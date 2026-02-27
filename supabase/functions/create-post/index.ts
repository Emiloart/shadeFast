import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import {
  extractMediaPath,
  inferMediaTypeFromPath,
  isOwnedMediaPath,
  type MediaType,
} from '../_shared/media.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type CreatePostPayload = {
  communityId?: string;
  content?: string;
  imageUrl?: string;
  videoUrl?: string;
  ttlHours?: number;
};

const mediaPolicyMaxAgeMs = 48 * 60 * 60 * 1000;

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

  let payload: CreatePostPayload;
  try {
    payload = (await req.json()) as CreatePostPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const content = payload.content?.trim() || null;
  const imageUrl = payload.imageUrl?.trim() || null;
  const videoUrl = payload.videoUrl?.trim() || null;

  if (!content && !imageUrl && !videoUrl) {
    return errorResponse(
      400,
      'missing_content',
      'Post requires text, image URL, or video URL.',
    );
  }

  if (content && content.length > 4000) {
    return errorResponse(
      400,
      'content_too_long',
      'Content must be 4000 characters or fewer.',
    );
  }

  if (imageUrl && !isValidHttpUrl(imageUrl)) {
    return errorResponse(400, 'invalid_image_url', 'Image URL must be valid.');
  }

  if (videoUrl && !isValidHttpUrl(videoUrl)) {
    return errorResponse(400, 'invalid_video_url', 'Video URL must be valid.');
  }

  const ttlHours = payload.ttlHours ?? 24;
  if (ttlHours !== 24 && ttlHours !== 48) {
    return errorResponse(400, 'invalid_ttl', 'ttlHours must be 24 or 48.');
  }

  const communityId = payload.communityId?.trim() || null;

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
        'This anonymous user is currently restricted from posting.',
      );
    }
  } catch (enforcementError) {
    console.error('create-post enforcement check failed', enforcementError);
    return errorResponse(
      500,
      'enforcement_check_failed',
      'Unable to validate enforcement status.',
    );
  }

  try {
    const postLimit = await checkAndBumpRateLimit(
      adminClient,
      user.id,
      'create_post_10m',
      10 * 60,
      12,
    );
    if (!postLimit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many posts in a short period. Please try again later.',
      );
    }
  } catch (rateError) {
    console.error('create-post rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate posting limits.',
    );
  }

  if (communityId) {
    const { data: community, error: communityError } = await adminClient
      .from('communities')
      .select('id, is_private, creator_uuid')
      .eq('id', communityId)
      .maybeSingle();

    if (communityError) {
      console.error('create-post community lookup failed', communityError);
      return errorResponse(
        500,
        'community_lookup_failed',
        'Unable to verify community.',
      );
    }

    if (!community) {
      return errorResponse(404, 'community_not_found', 'Community not found.');
    }

    if (community.is_private && community.creator_uuid !== user.id) {
      const { data: membership, error: membershipError } = await adminClient
        .from('community_memberships')
        .select('id')
        .eq('community_id', community.id)
        .eq('user_uuid', user.id)
        .maybeSingle();

      if (membershipError) {
        console.error('create-post membership lookup failed', membershipError);
        return errorResponse(
          500,
          'membership_lookup_failed',
          'Unable to verify private community membership.',
        );
      }

      if (!membership) {
        return errorResponse(
          403,
          'membership_required',
          'You are not a member of this private community.',
        );
      }
    }
  }

  if (imageUrl) {
    const imageCheckError = await validateMediaPolicyCheck(
      adminClient,
      user.id,
      imageUrl,
      'image',
    );
    if (imageCheckError) {
      return imageCheckError;
    }
  }

  if (videoUrl) {
    const videoCheckError = await validateMediaPolicyCheck(
      adminClient,
      user.id,
      videoUrl,
      'video',
    );
    if (videoCheckError) {
      return videoCheckError;
    }
  }

  const expiresAt = new Date(Date.now() + ttlHours * 60 * 60 * 1000).toISOString();

  const { data: post, error: postError } = await adminClient
    .from('posts')
    .insert({
      community_id: communityId,
      user_uuid: user.id,
      content,
      image_url: imageUrl,
      video_url: videoUrl,
      expires_at: expiresAt,
    })
    .select(
      'id, community_id, user_uuid, content, image_url, video_url, like_count, view_count, created_at, expires_at',
    )
    .single();

  if (postError) {
    console.error('create-post insert failed', postError);
    return errorResponse(500, 'post_create_failed', 'Unable to create post.');
  }

  return jsonResponse({ post }, 201);
});

function isValidHttpUrl(value: string): boolean {
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

async function validateMediaPolicyCheck(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
  mediaUrl: string,
  expectedType: MediaType,
): Promise<Response | null> {
  const objectPath = extractMediaPath(mediaUrl);
  if (!objectPath) {
    return errorResponse(
      400,
      'invalid_media_url',
      'Media URL must reference the ShadeFast media bucket.',
    );
  }

  if (!isOwnedMediaPath(objectPath, userId)) {
    return errorResponse(
      403,
      'media_not_owned',
      'Media must be uploaded by the current anonymous user.',
    );
  }

  const inferredType = inferMediaTypeFromPath(objectPath);
  if (!inferredType || inferredType !== expectedType) {
    return errorResponse(
      400,
      'invalid_media_type',
      'Media type does not match upload policy.',
    );
  }

  const { data: policyCheck, error: policyError } = await adminClient
    .from('media_policy_checks')
    .select('status, reason, checked_at')
    .eq('object_path', objectPath)
    .eq('user_uuid', userId)
    .order('checked_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (policyError) {
    console.error('create-post media policy lookup failed', policyError);
    return errorResponse(
      500,
      'media_policy_lookup_failed',
      'Unable to verify media safety checks.',
    );
  }

  if (!policyCheck) {
    return errorResponse(
      400,
      'media_policy_missing',
      'Media has not passed upload safety checks yet.',
    );
  }

  if (policyCheck.status === 'blocked') {
    return errorResponse(
      422,
      'media_policy_blocked',
      policyCheck.reason ?? 'Media violated upload safety checks.',
    );
  }

  if (policyCheck.status === 'error') {
    return errorResponse(
      503,
      'media_policy_error',
      'Media safety checks could not be completed. Please re-upload.',
    );
  }

  const checkedAtMs = new Date(policyCheck.checked_at).getTime();
  if (!Number.isFinite(checkedAtMs) || checkedAtMs < Date.now() - mediaPolicyMaxAgeMs) {
    return errorResponse(
      400,
      'media_policy_expired',
      'Media safety check expired. Please re-upload before posting.',
    );
  }

  return null;
}
