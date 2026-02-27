import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ListUserEntitlementsPayload = {
  includeExpired?: boolean;
  limit?: number;
};

const defaultLimit = 30;
const maxLimit = 100;

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

  let payload: ListUserEntitlementsPayload;
  try {
    payload = (await req.json()) as ListUserEntitlementsPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const includeExpired = payload.includeExpired ?? false;
  if (typeof includeExpired !== 'boolean') {
    return errorResponse(400, 'invalid_include_expired', 'includeExpired must be boolean.');
  }

  const limit = payload.limit ?? defaultLimit;
  if (!Number.isInteger(limit) || limit < 1 || limit > maxLimit) {
    return errorResponse(400, 'invalid_limit', `limit must be between 1 and ${maxLimit}.`);
  }

  let query = userClient
    .from('user_entitlements')
    .select(
      'id, user_uuid, product_id, status, source, started_at, expires_at, revoked_at, metadata, created_at, updated_at',
    )
    .eq('user_uuid', user.id)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (!includeExpired) {
    query = query.eq('status', 'active').is('revoked_at', null);
  }

  const { data: entitlements, error: entitlementsError } = await query;

  if (entitlementsError) {
    console.error('list-user-entitlements query failed', entitlementsError);
    return errorResponse(
      500,
      'user_entitlements_query_failed',
      'Unable to fetch user entitlements.',
    );
  }

  const nowMs = Date.now();
  const normalized = (entitlements ?? []).map((row) => {
    const expiresAt = row.expires_at;
    const expiresAtMs = typeof expiresAt === 'string' ? Date.parse(expiresAt) : NaN;
    const isActive =
      row.status === 'active' &&
      !row.revoked_at &&
      (!Number.isFinite(expiresAtMs) || expiresAtMs > nowMs);

    return {
      id: row.id,
      userUuid: row.user_uuid,
      productId: row.product_id,
      status: row.status,
      source: row.source,
      startedAt: row.started_at,
      expiresAt: row.expires_at,
      revokedAt: row.revoked_at,
      metadata: row.metadata,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      isActive,
    };
  });

  return jsonResponse({ entitlements: normalized }, 200);
});
