import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type EnforceUserPayload = {
  userUuid?: string;
  action?: 'warn' | 'ban_temp' | 'ban_permanent' | 'revoke';
  reason?: string;
  durationMinutes?: number;
  createdByUuid?: string;
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

  let payload: EnforceUserPayload;
  try {
    payload = (await req.json()) as EnforceUserPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const userUuid = payload.userUuid?.trim();
  if (!userUuid || !uuidPattern.test(userUuid)) {
    return errorResponse(400, 'invalid_user_uuid', 'userUuid must be a valid UUID.');
  }

  const action = payload.action;
  if (!action || !['warn', 'ban_temp', 'ban_permanent', 'revoke'].includes(action)) {
    return errorResponse(400, 'invalid_action', 'Unsupported enforcement action.');
  }

  const createdByUuid = payload.createdByUuid?.trim() || null;
  if (createdByUuid && !uuidPattern.test(createdByUuid)) {
    return errorResponse(
      400,
      'invalid_created_by_uuid',
      'createdByUuid must be a valid UUID.',
    );
  }

  const reason = payload.reason?.trim() || null;
  if (reason && reason.length > 500) {
    return errorResponse(400, 'reason_too_long', 'reason must be <= 500 chars.');
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  if (action === 'revoke') {
    const { error: revokeError } = await adminClient
      .from('enforcement_actions')
      .update({ revoked_at: new Date().toISOString() })
      .eq('user_uuid', userUuid)
      .is('revoked_at', null)
      .in('action', ['ban_temp', 'ban_permanent']);

    if (revokeError) {
      console.error('enforce-user revoke failed', revokeError);
      return errorResponse(500, 'enforcement_revoke_failed', 'Failed to revoke bans.');
    }
  } else {
    let expiresAt: string | null = null;
    if (action === 'ban_temp') {
      const durationMinutes = payload.durationMinutes ?? 60;
      if (
        !Number.isInteger(durationMinutes) ||
        durationMinutes < 1 ||
        durationMinutes > 60 * 24 * 365
      ) {
        return errorResponse(
          400,
          'invalid_duration_minutes',
          'durationMinutes must be between 1 and 525600.',
        );
      }

      expiresAt = new Date(Date.now() + durationMinutes * 60 * 1000).toISOString();
    }

    const { error: insertError } = await adminClient.from('enforcement_actions').insert({
      user_uuid: userUuid,
      action,
      reason,
      expires_at: expiresAt,
      created_by_uuid: createdByUuid,
    });

    if (insertError) {
      console.error('enforce-user insert failed', insertError);
      return errorResponse(
        500,
        'enforcement_insert_failed',
        'Failed to create enforcement action.',
      );
    }
  }

  const { data: activeBan, error: activeError } = await adminClient
    .from('enforcement_actions')
    .select('id, action, reason, expires_at, created_at')
    .eq('user_uuid', userUuid)
    .is('revoked_at', null)
    .in('action', ['ban_temp', 'ban_permanent'])
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (activeError) {
    console.error('enforce-user active status lookup failed', activeError);
    return errorResponse(
      500,
      'enforcement_status_failed',
      'Failed to fetch active enforcement status.',
    );
  }

  return jsonResponse(
    {
      userUuid,
      activeBan: activeBan ?? null,
      actionApplied: action,
    },
    200,
  );
});
