import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ReviewReportPayload = {
  reportId?: string;
  action?: 'in_review' | 'resolved' | 'dismissed';
  priority?: 'low' | 'normal' | 'high' | 'critical';
  resolutionNote?: string;
  reviewedByUuid?: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const allowedActions = new Set(['in_review', 'resolved', 'dismissed']);
const allowedPriorities = new Set(['low', 'normal', 'high', 'critical']);

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

  let payload: ReviewReportPayload;
  try {
    payload = (await req.json()) as ReviewReportPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const reportId = payload.reportId?.trim();
  if (!reportId || !uuidPattern.test(reportId)) {
    return errorResponse(400, 'invalid_report_id', 'reportId must be a valid UUID.');
  }

  const action = payload.action;
  if (!action || !allowedActions.has(action)) {
    return errorResponse(400, 'invalid_action', 'Unsupported review action.');
  }

  const priority = payload.priority ?? 'normal';
  if (!allowedPriorities.has(priority)) {
    return errorResponse(400, 'invalid_priority', 'Unsupported priority value.');
  }

  const reviewedByUuid = payload.reviewedByUuid?.trim() || null;
  if (reviewedByUuid && !uuidPattern.test(reviewedByUuid)) {
    return errorResponse(
      400,
      'invalid_reviewed_by_uuid',
      'reviewedByUuid must be a valid UUID when provided.',
    );
  }

  const resolutionNote = payload.resolutionNote?.trim() || null;
  if (resolutionNote && resolutionNote.length > 2000) {
    return errorResponse(
      400,
      'resolution_note_too_long',
      'resolutionNote must be <= 2000 chars.',
    );
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data, error } = await adminClient
    .from('reports')
    .update({
      status: action,
      priority,
      reviewed_at: new Date().toISOString(),
      reviewed_by_uuid: reviewedByUuid,
      resolution_note: resolutionNote,
    })
    .eq('id', reportId)
    .select(
      'id, post_id, reply_id, reason, details, reporter_uuid, created_at, status, priority, reviewed_at, reviewed_by_uuid, resolution_note',
    )
    .maybeSingle();

  if (error) {
    console.error('review-report update failed', error);
    return errorResponse(500, 'report_update_failed', 'Failed to update report.');
  }

  if (!data) {
    return errorResponse(404, 'report_not_found', 'Report not found.');
  }

  return jsonResponse(
    {
      report: data,
    },
    200,
  );
});
