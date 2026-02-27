import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type SetEntitlementPayload = {
  userUuid?: string;
  productId?: string;
  action?: 'grant' | 'revoke';
  durationDays?: number;
  source?: string;
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
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    return errorResponse(500, 'misconfigured_env', 'Missing function secrets.');
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const expected = `Bearer ${serviceRoleKey}`;
  if (authHeader.trim() !== expected) {
    return errorResponse(401, 'invalid_auth', 'Service role authorization required.');
  }

  let payload: SetEntitlementPayload;
  try {
    payload = (await req.json()) as SetEntitlementPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const userUuid = payload.userUuid?.trim();
  if (!userUuid || !uuidPattern.test(userUuid)) {
    return errorResponse(400, 'invalid_user_uuid', 'userUuid must be a valid UUID.');
  }

  const productId = payload.productId?.trim();
  if (!productId) {
    return errorResponse(400, 'invalid_product_id', 'productId is required.');
  }

  const action = payload.action;
  if (!action || (action !== 'grant' && action !== 'revoke')) {
    return errorResponse(400, 'invalid_action', 'action must be grant or revoke.');
  }

  const source = (payload.source?.trim() || 'admin').substring(0, 40);

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  if (action === 'revoke') {
    const { error: revokeError } = await adminClient
      .from('user_entitlements')
      .update({
        status: 'revoked',
        revoked_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('user_uuid', userUuid)
      .eq('product_id', productId)
      .eq('status', 'active')
      .is('revoked_at', null);

    if (revokeError) {
      console.error('set-entitlement revoke failed', revokeError);
      return errorResponse(500, 'entitlement_revoke_failed', 'Unable to revoke entitlement.');
    }
  } else {
    const durationDays = payload.durationDays ?? 30;
    if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 3650) {
      return errorResponse(
        400,
        'invalid_duration_days',
        'durationDays must be between 1 and 3650.',
      );
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

    const { error: revokePreviousError } = await adminClient
      .from('user_entitlements')
      .update({
        status: 'revoked',
        revoked_at: now.toISOString(),
        updated_at: now.toISOString(),
      })
      .eq('user_uuid', userUuid)
      .eq('product_id', productId)
      .eq('status', 'active')
      .is('revoked_at', null);

    if (revokePreviousError) {
      console.error('set-entitlement previous revoke failed', revokePreviousError);
      return errorResponse(
        500,
        'entitlement_previous_revoke_failed',
        'Unable to update previous entitlement state.',
      );
    }

    const { error: grantError } = await adminClient.from('user_entitlements').insert({
      user_uuid: userUuid,
      product_id: productId,
      status: 'active',
      source,
      started_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      metadata: { durationDays, source },
      updated_at: now.toISOString(),
    });

    if (grantError) {
      console.error('set-entitlement grant failed', grantError);
      return errorResponse(500, 'entitlement_grant_failed', 'Unable to grant entitlement.');
    }
  }

  const nowIso = new Date().toISOString();
  const { data: active, error: activeError } = await adminClient
    .from('user_entitlements')
    .select('id, product_id, status, source, started_at, expires_at, revoked_at')
    .eq('user_uuid', userUuid)
    .eq('product_id', productId)
    .eq('status', 'active')
    .is('revoked_at', null)
    .or(`expires_at.is.null,expires_at.gt.${nowIso}`)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (activeError) {
    console.error('set-entitlement active lookup failed', activeError);
    return errorResponse(500, 'entitlement_status_failed', 'Unable to fetch entitlement state.');
  }

  return jsonResponse(
    {
      userUuid,
      productId,
      actionApplied: action,
      activeEntitlement: active
        ? {
            id: active.id,
            productId: active.product_id,
            status: active.status,
            source: active.source,
            startedAt: active.started_at,
            expiresAt: active.expires_at,
            revokedAt: active.revoked_at,
          }
        : null,
    },
    200,
  );
});
