import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type VotePollPayload = {
  pollId?: string;
  optionIndex?: number;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'method_not_allowed', 'Use POST for this route.');
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return errorResponse(500, 'misconfigured_env', 'Missing function secrets.');
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return errorResponse(401, 'missing_auth', 'Missing bearer token.');
  }

  const accessToken = authHeader.replace('Bearer ', '').trim();
  const userClient = createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return errorResponse(401, 'invalid_auth', 'Invalid auth token.');
  }

  let payload: VotePollPayload;
  try {
    payload = (await req.json()) as VotePollPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const pollId = payload.pollId?.trim() ?? '';
  if (!uuidPattern.test(pollId)) {
    return errorResponse(400, 'invalid_poll_id', 'pollId must be a valid UUID.');
  }

  if (!Number.isInteger(payload.optionIndex)) {
    return errorResponse(400, 'invalid_option_index', 'optionIndex must be an integer.');
  }

  const optionIndex = payload.optionIndex!;

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  try {
    const banned = await isUserBanned(adminClient, user.id);
    if (banned) {
      return errorResponse(
        403,
        'banned_user',
        'This anonymous user is currently restricted from voting.',
      );
    }
  } catch (enforcementError) {
    console.error('vote-poll enforcement check failed', enforcementError);
    return errorResponse(
      500,
      'enforcement_check_failed',
      'Unable to validate enforcement status.',
    );
  }

  try {
    const limit = await checkAndBumpRateLimit(
      adminClient,
      user.id,
      'vote_poll_10m',
      10 * 60,
      120,
    );
    if (!limit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many votes in a short period. Please retry later.',
      );
    }
  } catch (rateError) {
    console.error('vote-poll rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate poll vote limits.',
    );
  }

  const { data: poll, error: pollError } = await adminClient
    .from('polls')
    .select('id, post_id, options')
    .eq('id', pollId)
    .maybeSingle();

  if (pollError) {
    console.error('vote-poll lookup failed', pollError);
    return errorResponse(500, 'poll_lookup_failed', 'Unable to fetch poll.');
  }

  if (!poll) {
    return errorResponse(404, 'poll_not_found', 'Poll not found.');
  }

  const options = normalizeOptions(poll.options);
  if (!options) {
    return errorResponse(500, 'invalid_poll_options', 'Poll options are invalid.');
  }

  if (optionIndex < 0 || optionIndex >= options.length) {
    return errorResponse(
      400,
      'option_index_out_of_bounds',
      'optionIndex is outside available options.',
    );
  }

  const { data: post, error: postError } = await adminClient
    .from('posts')
    .select('id, community_id, expires_at')
    .eq('id', poll.post_id)
    .maybeSingle();

  if (postError) {
    console.error('vote-poll post lookup failed', postError);
    return errorResponse(500, 'poll_post_lookup_failed', 'Unable to verify poll post.');
  }

  if (!post) {
    return errorResponse(404, 'poll_post_not_found', 'Poll post not found.');
  }

  if (new Date(post.expires_at).getTime() <= Date.now()) {
    return errorResponse(410, 'poll_expired', 'Poll has expired.');
  }

  if (post.community_id) {
    const canAccess = await canAccessCommunity(adminClient, post.community_id, user.id);
    if (!canAccess) {
      return errorResponse(
        403,
        'membership_required',
        'You are not allowed to vote in this private community poll.',
      );
    }
  }

  const { error: voteError } = await adminClient
    .from('poll_votes')
    .upsert(
      {
        poll_id: pollId,
        option_index: optionIndex,
        user_uuid: user.id,
        created_at: new Date().toISOString(),
      },
      {
        onConflict: 'poll_id,user_uuid',
      },
    );

  if (voteError) {
    console.error('vote-poll upsert failed', voteError);
    return errorResponse(500, 'poll_vote_failed', 'Unable to cast vote.');
  }

  const { data: votes, error: votesError } = await adminClient
    .from('poll_votes')
    .select('option_index')
    .eq('poll_id', pollId);

  if (votesError) {
    console.error('vote-poll tally lookup failed', votesError);
    return errorResponse(500, 'poll_tally_failed', 'Unable to compute vote tally.');
  }

  const counts = Array<number>(options.length).fill(0);
  for (const vote of votes ?? []) {
    const current = vote.option_index;
    if (typeof current === 'number' && current >= 0 && current < counts.length) {
      counts[current] += 1;
    }
  }

  return jsonResponse(
    {
      pollId,
      selectedOptionIndex: optionIndex,
      totalVotes: votes?.length ?? 0,
      counts,
    },
    200,
  );
});

function normalizeOptions(value: unknown): string[] | null {
  if (!Array.isArray(value)) {
    return null;
  }

  const options = value
    .map((item) => (typeof item === 'string' ? item.trim() : ''))
    .filter((item) => item.length > 0);

  return options.length >= 2 ? options : null;
}

async function canAccessCommunity(
  adminClient: ReturnType<typeof createClient>,
  communityId: string,
  userId: string,
): Promise<boolean> {
  const { data: community, error: communityError } = await adminClient
    .from('communities')
    .select('id, is_private, creator_uuid')
    .eq('id', communityId)
    .maybeSingle();

  if (communityError || !community) {
    if (communityError) {
      console.error('vote-poll community lookup failed', communityError);
    }
    return false;
  }

  if (!community.is_private || community.creator_uuid === userId) {
    return true;
  }

  const { data: membership, error: membershipError } = await adminClient
    .from('community_memberships')
    .select('id')
    .eq('community_id', communityId)
    .eq('user_uuid', userId)
    .maybeSingle();

  if (membershipError) {
    console.error('vote-poll membership lookup failed', membershipError);
    return false;
  }

  return Boolean(membership);
}
