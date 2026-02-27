import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ListTrendingPollsPayload = {
  limit?: number;
  communityId?: string;
};

type PollRow = {
  id: string;
  question: string;
  options: unknown;
  created_at: string;
  post: {
    id: string;
    community_id: string | null;
    content: string | null;
    like_count: number;
    created_at: string;
    expires_at: string;
  };
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const defaultLimit = 20;
const maxLimit = 50;

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

  let payload: ListTrendingPollsPayload;
  try {
    payload = (await req.json()) as ListTrendingPollsPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const limit = payload.limit ?? defaultLimit;
  if (!Number.isInteger(limit) || limit < 1 || limit > maxLimit) {
    return errorResponse(400, 'invalid_limit', `limit must be between 1 and ${maxLimit}.`);
  }

  const communityId = payload.communityId?.trim() || null;
  if (communityId && !uuidPattern.test(communityId)) {
    return errorResponse(400, 'invalid_community_id', 'communityId must be a valid UUID.');
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  if (communityId) {
    const canAccess = await canAccessCommunity(adminClient, communityId, user.id);
    if (!canAccess) {
      return errorResponse(
        403,
        'membership_required',
        'You are not allowed to view polls in this private community.',
      );
    }
  }

  const fetchLimit = Math.min(limit * 4, 200);
  let query = adminClient
    .from('polls')
    .select(
      'id, question, options, created_at, post:posts!inner(id, community_id, content, like_count, created_at, expires_at)',
    )
    .order('created_at', { ascending: false })
    .limit(fetchLimit);

  const { data: pollRows, error: pollsError } = await query;

  if (pollsError) {
    console.error('list-trending-polls query failed', pollsError);
    return errorResponse(500, 'polls_query_failed', 'Unable to fetch trending polls.');
  }

  const nowMs = Date.now();
  const visiblePolls: PollRow[] = [];

  for (const raw of (pollRows ?? []) as PollRow[]) {
    const post = raw.post;
    if (!post) {
      continue;
    }

    if (new Date(post.expires_at).getTime() <= nowMs) {
      continue;
    }

    if (communityId && post.community_id !== communityId) {
      continue;
    }

    if (post.community_id) {
      const canAccess = await canAccessCommunity(adminClient, post.community_id, user.id);
      if (!canAccess) {
        continue;
      }
    }

    visiblePolls.push(raw);
  }

  if (visiblePolls.length === 0) {
    return jsonResponse({ polls: [] }, 200);
  }

  const pollIds = visiblePolls.map((poll) => poll.id);

  const { data: votes, error: votesError } = await adminClient
    .from('poll_votes')
    .select('poll_id, option_index')
    .in('poll_id', pollIds);

  if (votesError) {
    console.error('list-trending-polls votes query failed', votesError);
    return errorResponse(500, 'poll_votes_query_failed', 'Unable to fetch poll votes.');
  }

  const { data: userVotes, error: userVotesError } = await adminClient
    .from('poll_votes')
    .select('poll_id, option_index')
    .eq('user_uuid', user.id)
    .in('poll_id', pollIds);

  if (userVotesError) {
    console.error('list-trending-polls user votes query failed', userVotesError);
    return errorResponse(500, 'poll_user_votes_query_failed', 'Unable to fetch your votes.');
  }

  const voteMap = new Map<string, number[]>();
  for (const poll of visiblePolls) {
    const options = normalizeOptions(poll.options);
    voteMap.set(poll.id, Array(options.length).fill(0));
  }

  for (const vote of votes ?? []) {
    const pollId = vote.poll_id as string | null;
    const optionIndex = vote.option_index as number | null;
    if (!pollId || typeof optionIndex !== 'number') {
      continue;
    }

    const counts = voteMap.get(pollId);
    if (!counts || optionIndex < 0 || optionIndex >= counts.length) {
      continue;
    }

    counts[optionIndex] += 1;
  }

  const userVoteMap = new Map<string, number>();
  for (const vote of userVotes ?? []) {
    const pollId = vote.poll_id as string | null;
    const optionIndex = vote.option_index as number | null;
    if (pollId && typeof optionIndex === 'number') {
      userVoteMap.set(pollId, optionIndex);
    }
  }

  const ranked = visiblePolls
    .map((poll) => {
      const options = normalizeOptions(poll.options);
      const counts = voteMap.get(poll.id) ?? Array(options.length).fill(0);
      const totalVotes = counts.reduce((sum, count) => sum + count, 0);
      const trendScore = totalVotes * 2 + poll.post.like_count;

      return {
        id: poll.id,
        question: poll.question,
        options,
        counts,
        totalVotes,
        trendScore,
        selectedOptionIndex: userVoteMap.get(poll.id) ?? null,
        createdAt: poll.created_at,
        post: {
          id: poll.post.id,
          communityId: poll.post.community_id,
          content: poll.post.content,
          likeCount: poll.post.like_count,
          createdAt: poll.post.created_at,
          expiresAt: poll.post.expires_at,
        },
      };
    })
    .sort((a, b) => {
      if (b.trendScore !== a.trendScore) {
        return b.trendScore - a.trendScore;
      }
      return Date.parse(b.createdAt) - Date.parse(a.createdAt);
    })
    .slice(0, limit);

  return jsonResponse({ polls: ranked }, 200);
});

function normalizeOptions(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => (typeof item === 'string' ? item.trim() : ''))
    .filter((item) => item.length > 0);
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
      console.error('list-trending-polls community lookup failed', communityError);
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
    console.error('list-trending-polls membership lookup failed', membershipError);
    return false;
  }

  return Boolean(membership);
}
