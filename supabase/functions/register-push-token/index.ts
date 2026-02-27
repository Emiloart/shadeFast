import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type RegisterPushTokenPayload = {
  token?: string;
  platform?: string;
  locale?: string;
  appVersion?: string;
};

const allowedPlatforms = new Set(['ios', 'android', 'web']);

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

  let payload: RegisterPushTokenPayload;
  try {
    payload = (await req.json()) as RegisterPushTokenPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const token = payload.token?.trim() ?? '';
  if (token.length < 16 || token.length > 4096) {
    return errorResponse(400, 'invalid_token', 'Push token must be between 16 and 4096 characters.');
  }

  const platform = payload.platform?.trim().toLowerCase() ?? '';
  if (!allowedPlatforms.has(platform)) {
    return errorResponse(
      400,
      'invalid_platform',
      'platform must be one of ios, android, or web.',
    );
  }

  const locale = normalizeOptional(payload.locale, 24);
  const appVersion = normalizeOptional(payload.appVersion, 40);

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
        'This anonymous user is currently restricted from registering notifications.',
      );
    }
  } catch (enforcementError) {
    console.error('register-push-token enforcement check failed', enforcementError);
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
      'register_push_token_1h',
      60 * 60,
      30,
    );
    if (!limit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many token registration attempts. Please retry later.',
      );
    }
  } catch (rateError) {
    console.error('register-push-token rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate registration limits.',
    );
  }

  const nowIso = new Date().toISOString();
  const { data: row, error: upsertError } = await adminClient
    .from('push_tokens')
    .upsert(
      {
        user_uuid: user.id,
        token,
        platform,
        locale,
        app_version: appVersion,
        last_seen_at: nowIso,
        revoked_at: null,
      },
      { onConflict: 'token' },
    )
    .select('id, user_uuid, token, platform, locale, app_version, last_seen_at, revoked_at')
    .single();

  if (upsertError) {
    console.error('register-push-token upsert failed', upsertError);
    return errorResponse(
      500,
      'push_token_register_failed',
      'Unable to register push token.',
    );
  }

  return jsonResponse(
    {
      registration: {
        id: row.id,
        userUuid: row.user_uuid,
        token: row.token,
        platform: row.platform,
        locale: row.locale,
        appVersion: row.app_version,
        lastSeenAt: row.last_seen_at,
        revokedAt: row.revoked_at,
      },
    },
    200,
  );
});

function normalizeOptional(value: string | undefined, maxLength: number): string | null {
  const trimmed = value?.trim();
  if (!trimmed) {
    return null;
  }

  return trimmed.substring(0, maxLength);
}
