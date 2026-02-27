import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type ActivatePremiumTrialPayload = {
  days?: number;
};

const defaultTrialDays = 3;
const maxTrialDays = 7;

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

  let payload: ActivatePremiumTrialPayload;
  try {
    payload = (await req.json()) as ActivatePremiumTrialPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const days = payload.days ?? defaultTrialDays;
  if (!Number.isInteger(days) || days < 1 || days > maxTrialDays) {
    return errorResponse(
      400,
      'invalid_trial_days',
      `days must be between 1 and ${maxTrialDays}.`,
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
        'This anonymous user is currently restricted from activating trial.',
      );
    }
  } catch (enforcementError) {
    console.error('activate-premium-trial enforcement check failed', enforcementError);
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
      'activate_premium_trial_1d',
      24 * 60 * 60,
      3,
    );
    if (!limit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many trial activation attempts. Please retry later.',
      );
    }
  } catch (rateError) {
    console.error('activate-premium-trial rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate trial activation limits.',
    );
  }

  const { data: existingTrials, error: trialLookupError } = await adminClient
    .from('user_entitlements')
    .select('id')
    .eq('user_uuid', user.id)
    .eq('source', 'trial')
    .limit(1);

  if (trialLookupError) {
    console.error('activate-premium-trial existing trial lookup failed', trialLookupError);
    return errorResponse(
      500,
      'trial_lookup_failed',
      'Unable to validate trial history.',
    );
  }

  if ((existingTrials ?? []).isNotEmpty) {
    return errorResponse(409, 'trial_already_used', 'Premium trial has already been used.');
  }

  const now = new Date();
  const expiresAt = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

  const { data: entitlement, error: insertError } = await adminClient
    .from('user_entitlements')
    .insert({
      user_uuid: user.id,
      product_id: 'premium_monthly',
      status: 'active',
      source: 'trial',
      started_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      metadata: { trial: true, trialDays: days },
      updated_at: now.toISOString(),
    })
    .select('id, product_id, status, source, started_at, expires_at')
    .single();

  if (insertError) {
    console.error('activate-premium-trial insert failed', insertError);
    return errorResponse(
      500,
      'trial_activation_failed',
      'Unable to activate premium trial.',
    );
  }

  return jsonResponse(
    {
      entitlement: {
        id: entitlement.id,
        productId: entitlement.product_id,
        status: entitlement.status,
        source: entitlement.source,
        startedAt: entitlement.started_at,
        expiresAt: entitlement.expires_at,
      },
    },
    201,
  );
});
