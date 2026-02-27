import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ListReportsPayload = {
  status?: 'open' | 'in_review' | 'resolved' | 'dismissed';
  limit?: number;
  beforeCreatedAt?: string;
};

const defaultLimit = 50;
const maxLimit = 200;
const allowedStatuses = new Set(['open', 'in_review', 'resolved', 'dismissed']);

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

  let payload: ListReportsPayload;
  try {
    payload = (await req.json()) as ListReportsPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const status = payload.status ?? 'open';
  if (!allowedStatuses.has(status)) {
    return errorResponse(400, 'invalid_status', 'Unsupported report status.');
  }

  const limit = payload.limit ?? defaultLimit;
  if (!Number.isInteger(limit) || limit < 1 || limit > maxLimit) {
    return errorResponse(
      400,
      'invalid_limit',
      `limit must be between 1 and ${maxLimit}.`,
    );
  }

  const beforeCreatedAt = payload.beforeCreatedAt?.trim();
  if (beforeCreatedAt) {
    const parsed = Date.parse(beforeCreatedAt);
    if (Number.isNaN(parsed)) {
      return errorResponse(
        400,
        'invalid_before_created_at',
        'beforeCreatedAt must be an ISO datetime.',
      );
    }
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  let query = adminClient
    .from('reports')
    .select(
      'id, post_id, reply_id, reason, details, reporter_uuid, created_at, status, priority, reviewed_at, reviewed_by_uuid, resolution_note',
    )
    .eq('status', status)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (beforeCreatedAt) {
    query = query.lt('created_at', beforeCreatedAt);
  }

  const { data, error } = await query;
  if (error) {
    console.error('list-reports query failed', error);
    return errorResponse(500, 'reports_query_failed', 'Failed to list reports.');
  }

  return jsonResponse(
    {
      reports: data ?? [],
    },
    200,
  );
});
