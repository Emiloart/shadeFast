import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type SubmitChallengeEntryPayload = {
  challengeId?: string;
  postId?: string;
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

  let payload: SubmitChallengeEntryPayload;
  try {
    payload = (await req.json()) as SubmitChallengeEntryPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const challengeId = payload.challengeId?.trim() ?? '';
  if (!uuidPattern.test(challengeId)) {
    return errorResponse(
      400,
      'invalid_challenge_id',
      'challengeId must be a valid UUID.',
    );
  }

  const postId = payload.postId?.trim() ?? '';
  if (!uuidPattern.test(postId)) {
    return errorResponse(400, 'invalid_post_id', 'postId must be a valid UUID.');
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
        'This anonymous user is currently restricted from submitting challenge entries.',
      );
    }
  } catch (enforcementError) {
    console.error('submit-challenge-entry enforcement check failed', enforcementError);
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
      'submit_challenge_entry_10m',
      10 * 60,
      50,
    );
    if (!limit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many challenge entries submitted recently. Please retry later.',
      );
    }
  } catch (rateError) {
    console.error('submit-challenge-entry rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate challenge entry limits.',
    );
  }

  const { data: challenge, error: challengeError } = await adminClient
    .from('challenges')
    .select('id, expires_at')
    .eq('id', challengeId)
    .maybeSingle();

  if (challengeError) {
    console.error('submit-challenge-entry challenge lookup failed', challengeError);
    return errorResponse(500, 'challenge_lookup_failed', 'Unable to verify challenge.');
  }

  if (!challenge) {
    return errorResponse(404, 'challenge_not_found', 'Challenge not found.');
  }

  if (new Date(challenge.expires_at).getTime() <= Date.now()) {
    return errorResponse(410, 'challenge_expired', 'Challenge has expired.');
  }

  const { data: post, error: postError } = await adminClient
    .from('posts')
    .select('id, user_uuid, expires_at')
    .eq('id', postId)
    .maybeSingle();

  if (postError) {
    console.error('submit-challenge-entry post lookup failed', postError);
    return errorResponse(500, 'post_lookup_failed', 'Unable to verify post.');
  }

  if (!post) {
    return errorResponse(404, 'post_not_found', 'Post not found.');
  }

  if (post.user_uuid !== user.id) {
    return errorResponse(
      403,
      'not_post_owner',
      'Only your own post can be submitted as a challenge entry.',
    );
  }

  if (new Date(post.expires_at).getTime() <= Date.now()) {
    return errorResponse(410, 'post_expired', 'Cannot submit expired posts.');
  }

  const { data: entry, error: entryError } = await adminClient
    .from('challenge_entries')
    .upsert(
      {
        challenge_id: challengeId,
        post_id: postId,
        user_uuid: user.id,
      },
      {
        onConflict: 'challenge_id,post_id',
      },
    )
    .select('id, challenge_id, post_id, user_uuid, created_at')
    .single();

  if (entryError) {
    console.error('submit-challenge-entry upsert failed', entryError);
    return errorResponse(
      500,
      'challenge_entry_submit_failed',
      'Unable to submit challenge entry.',
    );
  }

  return jsonResponse({ entry }, 201);
});
