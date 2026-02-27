import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type CreatePollPayload = {
  communityId?: string;
  content?: string;
  question?: string;
  options?: string[];
  ttlHours?: number;
  challengeId?: string;
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

  let payload: CreatePollPayload;
  try {
    payload = (await req.json()) as CreatePollPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const question = payload.question?.trim() ?? '';
  if (question.length < 3 || question.length > 280) {
    return errorResponse(
      400,
      'invalid_question',
      'Question must be between 3 and 280 characters.',
    );
  }

  if (!Array.isArray(payload.options)) {
    return errorResponse(400, 'invalid_options', 'Options must be an array.');
  }

  const options = payload.options
    .map((option) => (typeof option === 'string' ? option.trim() : ''))
    .filter((option) => option.length > 0);

  if (options.length < 2 || options.length > 6) {
    return errorResponse(
      400,
      'invalid_options',
      'Provide between 2 and 6 non-empty options.',
    );
  }

  if (options.some((option) => option.length > 80)) {
    return errorResponse(
      400,
      'option_too_long',
      'Each option must be 80 characters or fewer.',
    );
  }

  const uniqueOptions = new Set(options.map((option) => option.toLowerCase()));
  if (uniqueOptions.size !== options.length) {
    return errorResponse(
      400,
      'duplicate_options',
      'Poll options must be unique.',
    );
  }

  const content = payload.content?.trim() || null;
  if (content && content.length > 4000) {
    return errorResponse(
      400,
      'content_too_long',
      'Content must be 4000 characters or fewer.',
    );
  }

  const ttlHours = payload.ttlHours ?? 24;
  if (ttlHours !== 24 && ttlHours !== 48) {
    return errorResponse(400, 'invalid_ttl', 'ttlHours must be 24 or 48.');
  }

  const communityId = payload.communityId?.trim() || null;
  if (communityId && !uuidPattern.test(communityId)) {
    return errorResponse(
      400,
      'invalid_community_id',
      'communityId must be a valid UUID.',
    );
  }

  const challengeId = payload.challengeId?.trim() || null;
  if (challengeId && !uuidPattern.test(challengeId)) {
    return errorResponse(
      400,
      'invalid_challenge_id',
      'challengeId must be a valid UUID.',
    );
  }

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
        'This anonymous user is currently restricted from creating polls.',
      );
    }
  } catch (enforcementError) {
    console.error('create-poll enforcement check failed', enforcementError);
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
      'create_poll_10m',
      10 * 60,
      8,
    );
    if (!limit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many polls created in a short period. Please retry later.',
      );
    }
  } catch (rateError) {
    console.error('create-poll rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate poll creation limits.',
    );
  }

  if (communityId) {
    const communityCheckError = await validateCommunityAccess(
      adminClient,
      communityId,
      user.id,
    );
    if (communityCheckError) {
      return communityCheckError;
    }
  }

  if (challengeId) {
    const challengeCheckError = await validateChallengeAvailability(
      adminClient,
      challengeId,
    );
    if (challengeCheckError) {
      return challengeCheckError;
    }
  }

  const expiresAt = new Date(Date.now() + ttlHours * 60 * 60 * 1000).toISOString();

  const { data: post, error: postError } = await adminClient
    .from('posts')
    .insert({
      community_id: communityId,
      user_uuid: user.id,
      content,
      expires_at: expiresAt,
    })
    .select(
      'id, community_id, user_uuid, content, image_url, video_url, like_count, view_count, created_at, expires_at',
    )
    .single();

  if (postError) {
    console.error('create-poll post insert failed', postError);
    return errorResponse(500, 'poll_post_create_failed', 'Unable to create poll post.');
  }

  const { data: poll, error: pollError } = await adminClient
    .from('polls')
    .insert({
      post_id: post.id,
      question,
      options,
    })
    .select('id, post_id, question, options, created_at')
    .single();

  if (pollError) {
    console.error('create-poll insert failed', pollError);
    await adminClient.from('posts').delete().eq('id', post.id);
    return errorResponse(500, 'poll_create_failed', 'Unable to create poll.');
  }

  if (challengeId) {
    const { error: challengeEntryError } = await adminClient
      .from('challenge_entries')
      .insert({
        challenge_id: challengeId,
        post_id: post.id,
        user_uuid: user.id,
      });

    if (challengeEntryError) {
      console.error('create-poll challenge entry insert failed', challengeEntryError);
    }
  }

  return jsonResponse(
    {
      poll: {
        ...poll,
        options,
      },
      post,
    },
    201,
  );
});

async function validateCommunityAccess(
  adminClient: ReturnType<typeof createClient>,
  communityId: string,
  userId: string,
): Promise<Response | null> {
  const { data: community, error: communityError } = await adminClient
    .from('communities')
    .select('id, is_private, creator_uuid')
    .eq('id', communityId)
    .maybeSingle();

  if (communityError) {
    console.error('create-poll community lookup failed', communityError);
    return errorResponse(
      500,
      'community_lookup_failed',
      'Unable to verify community.',
    );
  }

  if (!community) {
    return errorResponse(404, 'community_not_found', 'Community not found.');
  }

  if (community.is_private && community.creator_uuid !== userId) {
    const { data: membership, error: membershipError } = await adminClient
      .from('community_memberships')
      .select('id')
      .eq('community_id', communityId)
      .eq('user_uuid', userId)
      .maybeSingle();

    if (membershipError) {
      console.error('create-poll membership lookup failed', membershipError);
      return errorResponse(
        500,
        'membership_lookup_failed',
        'Unable to verify private community membership.',
      );
    }

    if (!membership) {
      return errorResponse(
        403,
        'membership_required',
        'You are not a member of this private community.',
      );
    }
  }

  return null;
}

async function validateChallengeAvailability(
  adminClient: ReturnType<typeof createClient>,
  challengeId: string,
): Promise<Response | null> {
  const { data: challenge, error: challengeError } = await adminClient
    .from('challenges')
    .select('id, expires_at')
    .eq('id', challengeId)
    .maybeSingle();

  if (challengeError) {
    console.error('create-poll challenge lookup failed', challengeError);
    return errorResponse(
      500,
      'challenge_lookup_failed',
      'Unable to verify challenge.',
    );
  }

  if (!challenge) {
    return errorResponse(404, 'challenge_not_found', 'Challenge not found.');
  }

  if (new Date(challenge.expires_at).getTime() <= Date.now()) {
    return errorResponse(410, 'challenge_expired', 'Challenge has expired.');
  }

  return null;
}
