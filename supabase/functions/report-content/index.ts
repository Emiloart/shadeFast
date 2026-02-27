import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type ReportPayload = {
  postId?: string;
  replyId?: string;
  reason?: string;
  details?: string;
};

const allowedReasons = new Set<string>([
  'spam',
  'harassment',
  'hate',
  'violence',
  'sexual',
  'self_harm',
  'misinformation',
  'other',
]);

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

  let payload: ReportPayload;
  try {
    payload = (await req.json()) as ReportPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const postId = payload.postId?.trim();
  const replyId = payload.replyId?.trim();

  if (!postId && !replyId) {
    return errorResponse(400, 'missing_target', 'Provide postId or replyId.');
  }

  if (postId && replyId) {
    return errorResponse(400, 'ambiguous_target', 'Provide only one target type.');
  }

  if (postId && !uuidPattern.test(postId)) {
    return errorResponse(400, 'invalid_post_id', 'postId must be a valid UUID.');
  }

  if (replyId && !uuidPattern.test(replyId)) {
    return errorResponse(400, 'invalid_reply_id', 'replyId must be a valid UUID.');
  }

  const reason = (payload.reason ?? '').trim().toLowerCase();
  if (!allowedReasons.has(reason)) {
    return errorResponse(400, 'invalid_reason', 'Unsupported report reason.');
  }

  const details = payload.details?.trim() || null;
  if (details && details.length > 1000) {
    return errorResponse(400, 'details_too_long', 'Details must be <= 1000 chars.');
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
        'This anonymous user is currently restricted from reporting.',
      );
    }
  } catch (enforcementError) {
    console.error('report-content enforcement check failed', enforcementError);
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
      'report_content_1h',
      60 * 60,
      40,
    );
    if (!limit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many reports submitted recently. Please wait and retry.',
      );
    }
  } catch (rateError) {
    console.error('report-content rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate reporting limits.',
    );
  }

  const targetPostId = postId
    ? postId
    : await resolvePostIdForReply(adminClient, replyId!);

  if (!targetPostId) {
    return errorResponse(404, 'target_not_found', 'Target content not found.');
  }

  const post = await fetchPost(adminClient, targetPostId);
  if (!post) {
    return errorResponse(404, 'post_not_found', 'Post not found.');
  }

  if (new Date(post.expires_at).getTime() <= Date.now()) {
    return errorResponse(410, 'content_expired', 'Cannot report expired content.');
  }

  if (post.community_id) {
    const canAccess = await canAccessCommunity(adminClient, post.community_id, user.id);
    if (!canAccess) {
      return errorResponse(
        403,
        'community_access_denied',
        'You cannot report content in this private community.',
      );
    }
  }

  const { data: report, error: reportError } = await adminClient
    .from('reports')
    .insert({
      post_id: postId ? postId : null,
      reply_id: replyId ?? null,
      reason,
      details,
      reporter_uuid: user.id,
    })
    .select('id, created_at')
    .single();

  if (reportError) {
    console.error('report-content insert failed', reportError);
    return errorResponse(500, 'report_insert_failed', 'Failed to submit report.');
  }

  return jsonResponse(
    {
      ok: true,
      reportId: report.id,
      createdAt: report.created_at,
    },
    201,
  );
});

async function resolvePostIdForReply(
  adminClient: ReturnType<typeof createClient>,
  replyId: string,
): Promise<string | null> {
  const { data, error } = await adminClient
    .from('replies')
    .select('post_id')
    .eq('id', replyId)
    .maybeSingle();

  if (error) {
    console.error('report-content reply lookup failed', error);
    return null;
  }

  return data?.post_id ?? null;
}

async function fetchPost(
  adminClient: ReturnType<typeof createClient>,
  postId: string,
): Promise<{ community_id: string | null; expires_at: string } | null> {
  const { data, error } = await adminClient
    .from('posts')
    .select('community_id, expires_at')
    .eq('id', postId)
    .maybeSingle();

  if (error) {
    console.error('report-content post lookup failed', error);
    return null;
  }

  return data;
}

async function canAccessCommunity(
  adminClient: ReturnType<typeof createClient>,
  communityId: string,
  userId: string,
): Promise<boolean> {
  const { data: community, error: communityError } = await adminClient
    .from('communities')
    .select('id, is_private, creator_uuid')
    .eq('id', communityId)
    .maybeSingle();

  if (communityError || !community) {
    if (communityError) {
      console.error('report-content community lookup failed', communityError);
    }
    return false;
  }

  if (!community.is_private || community.creator_uuid === userId) {
    return true;
  }

  const { data: membership, error: membershipError } = await adminClient
    .from('community_memberships')
    .select('id')
    .eq('community_id', community.id)
    .eq('user_uuid', userId)
    .maybeSingle();

  if (membershipError) {
    console.error('report-content membership lookup failed', membershipError);
    return false;
  }

  return Boolean(membership);
}
