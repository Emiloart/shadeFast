import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type CreateChallengePayload = {
  title?: string;
  description?: string;
  durationDays?: number;
};

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

  let payload: CreateChallengePayload;
  try {
    payload = (await req.json()) as CreateChallengePayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const title = payload.title?.trim() ?? '';
  if (title.length < 3 || title.length > 120) {
    return errorResponse(
      400,
      'invalid_title',
      'Title must be between 3 and 120 characters.',
    );
  }

  const description = payload.description?.trim() || null;
  if (description && description.length > 1000) {
    return errorResponse(
      400,
      'description_too_long',
      'Description must be 1000 characters or fewer.',
    );
  }

  const durationDays = payload.durationDays ?? 7;
  if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 14) {
    return errorResponse(
      400,
      'invalid_duration_days',
      'durationDays must be between 1 and 14.',
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
        'This anonymous user is currently restricted from creating challenges.',
      );
    }
  } catch (enforcementError) {
    console.error('create-challenge enforcement check failed', enforcementError);
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
      'create_challenge_1h',
      60 * 60,
      12,
    );
    if (!limit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many challenges created recently. Please retry later.',
      );
    }
  } catch (rateError) {
    console.error('create-challenge rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate challenge creation limits.',
    );
  }

  const expiresAt = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();

  const { data: challenge, error: challengeError } = await adminClient
    .from('challenges')
    .insert({
      title,
      description,
      creator_uuid: user.id,
      expires_at: expiresAt,
    })
    .select('id, title, description, creator_uuid, created_at, expires_at')
    .single();

  if (challengeError) {
    console.error('create-challenge insert failed', challengeError);
    return errorResponse(500, 'challenge_create_failed', 'Unable to create challenge.');
  }

  return jsonResponse({ challenge }, 201);
});
