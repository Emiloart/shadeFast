import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ListTrendingChallengesPayload = {
  limit?: number;
};

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

  if (!supabaseUrl || !anonKey) {
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

  let payload: ListTrendingChallengesPayload;
  try {
    payload = (await req.json()) as ListTrendingChallengesPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const limit = payload.limit ?? defaultLimit;
  if (!Number.isInteger(limit) || limit < 1 || limit > maxLimit) {
    return errorResponse(400, 'invalid_limit', `limit must be between 1 and ${maxLimit}.`);
  }

  const nowIso = new Date().toISOString();
  const fetchLimit = Math.min(limit * 4, 200);

  const { data: challenges, error: challengesError } = await userClient
    .from('challenges')
    .select('id, title, description, creator_uuid, created_at, expires_at')
    .gt('expires_at', nowIso)
    .order('created_at', { ascending: false })
    .limit(fetchLimit);

  if (challengesError) {
    console.error('list-trending-challenges query failed', challengesError);
    return errorResponse(500, 'challenges_query_failed', 'Unable to fetch challenges.');
  }

  if (!challenges || challenges.length === 0) {
    return jsonResponse({ challenges: [] }, 200);
  }

  const challengeIds = challenges.map((challenge) => challenge.id);

  const { data: entries, error: entriesError } = await userClient
    .from('challenge_entries')
    .select('challenge_id, user_uuid, created_at')
    .in('challenge_id', challengeIds);

  if (entriesError) {
    console.error('list-trending-challenges entries query failed', entriesError);
    return errorResponse(500, 'challenge_entries_query_failed', 'Unable to fetch challenge activity.');
  }

  const entryCountByChallenge = new Map<string, number>();
  const recentEntryCountByChallenge = new Map<string, number>();
  const participantSetByChallenge = new Map<string, Set<string>>();
  const recentCutoff = Date.now() - 24 * 60 * 60 * 1000;

  for (const entry of entries ?? []) {
    const challengeId = entry.challenge_id as string | null;
    const userId = entry.user_uuid as string | null;
    if (!challengeId) {
      continue;
    }

    entryCountByChallenge.set(
      challengeId,
      (entryCountByChallenge.get(challengeId) ?? 0) + 1,
    );

    if (userId) {
      const participants = participantSetByChallenge.get(challengeId) ?? new Set<string>();
      participants.add(userId);
      participantSetByChallenge.set(challengeId, participants);
    }

    const createdAtMs = Date.parse(String(entry.created_at));
    if (Number.isFinite(createdAtMs) && createdAtMs >= recentCutoff) {
      recentEntryCountByChallenge.set(
        challengeId,
        (recentEntryCountByChallenge.get(challengeId) ?? 0) + 1,
      );
    }
  }

  const ranked = challenges
    .map((challenge) => {
      const entryCount = entryCountByChallenge.get(challenge.id) ?? 0;
      const recentEntryCount = recentEntryCountByChallenge.get(challenge.id) ?? 0;
      const participantCount = participantSetByChallenge.get(challenge.id)?.size ?? 0;
      const trendScore = entryCount * 2 + recentEntryCount * 3 + participantCount;

      return {
        id: challenge.id,
        title: challenge.title,
        description: challenge.description,
        creatorUuid: challenge.creator_uuid,
        createdAt: challenge.created_at,
        expiresAt: challenge.expires_at,
        entryCount,
        recentEntryCount,
        participantCount,
        trendScore,
      };
    })
    .sort((a, b) => {
      if (b.trendScore !== a.trendScore) {
        return b.trendScore - a.trendScore;
      }
      return Date.parse(b.createdAt) - Date.parse(a.createdAt);
    })
    .slice(0, limit);

  return jsonResponse({ challenges: ranked }, 200);
});
