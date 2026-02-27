import { createClient, type SupabaseClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import {
  extractMediaPath,
  inferMediaTypeFromPath,
  isOwnedMediaPath,
  type MediaType,
} from '../_shared/media.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type ModerateUploadPayload = {
  mediaUrl?: string;
  objectPath?: string;
  mediaType?: MediaType;
};

type PolicyVerdict = {
  status: 'approved' | 'blocked' | 'error';
  provider: string;
  providerReference?: string | null;
  reason?: string | null;
  confidence?: number | null;
  labels?: string[] | null;
};

const maxImageBytes = 8 * 1024 * 1024;
const maxVideoBytes = 10 * 1024 * 1024;
const signedUrlTtlSeconds = 5 * 60;
const allowedImageMimes = new Set<string>([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);
const allowedVideoMimes = new Set<string>([
  'video/mp4',
  'video/quicktime',
  'video/webm',
]);

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

  let payload: ModerateUploadPayload;
  try {
    payload = (await req.json()) as ModerateUploadPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const objectPath = resolveObjectPath(payload);
  if (!objectPath) {
    return errorResponse(
      400,
      'missing_media_target',
      'Provide a valid objectPath or mediaUrl.',
    );
  }

  if (!isOwnedMediaPath(objectPath, user.id)) {
    return errorResponse(
      403,
      'media_not_owned',
      'Media must be uploaded by the current anonymous user.',
    );
  }

  const mediaType = resolveMediaType(payload, objectPath);
  if (!mediaType) {
    return errorResponse(
      400,
      'invalid_media_type',
      'Media type must be image or video and match object path.',
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
        'This anonymous user is currently restricted from uploading media.',
      );
    }
  } catch (enforcementError) {
    console.error('moderate-upload enforcement check failed', enforcementError);
    return errorResponse(
      500,
      'enforcement_check_failed',
      'Unable to validate enforcement status.',
    );
  }

  try {
    const rate = await checkAndBumpRateLimit(
      adminClient,
      user.id,
      'moderate_upload_10m',
      10 * 60,
      30,
    );
    if (!rate.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many media uploads in a short period. Please retry later.',
      );
    }
  } catch (rateError) {
    console.error('moderate-upload rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate upload limits.',
    );
  }

  const { data: fileBlob, error: downloadError } = await adminClient.storage
    .from('media')
    .download(objectPath);

  if (downloadError || !fileBlob) {
    if (downloadError) {
      console.error('moderate-upload storage download failed', downloadError);
    }

    return errorResponse(404, 'media_not_found', 'Uploaded media was not found.');
  }

  const bytes = await blobToBytes(fileBlob);
  if (!bytes) {
    const verdict: PolicyVerdict = {
      status: 'error',
      provider: 'builtin',
      reason: 'unable_to_read_media',
    };

    await persistPolicyCheck(
      adminClient,
      user.id,
      objectPath,
      mediaType,
      null,
      0,
      verdict,
    );

    return errorResponse(
      500,
      'media_read_failed',
      'Unable to inspect uploaded media. Please retry upload.',
    );
  }

  const byteSize = bytes.byteLength;
  const mimeType = detectMimeType(bytes, objectPath);
  let verdict = evaluateBuiltinPolicy(mediaType, mimeType, byteSize);

  if (verdict.status === 'approved') {
    const webhookVerdict = await runWebhookPolicyCheck(
      adminClient,
      user.id,
      objectPath,
      mediaType,
      mimeType,
      byteSize,
    );

    if (webhookVerdict) {
      verdict = webhookVerdict;
    }
  }

  await persistPolicyCheck(
    adminClient,
    user.id,
    objectPath,
    mediaType,
    mimeType,
    byteSize,
    verdict,
  );

  if (verdict.status === 'blocked') {
    await removeMediaObject(adminClient, objectPath);
    return errorResponse(
      422,
      'media_blocked',
      verdict.reason ?? 'Upload blocked by safety policy.',
    );
  }

  if (verdict.status === 'error') {
    const strictMode = parseBoolean(Deno.env.get('UPLOAD_POLICY_STRICT_MODE'));
    if (strictMode) {
      await removeMediaObject(adminClient, objectPath);
      return errorResponse(
        503,
        'policy_provider_unavailable',
        'Media safety checks are temporarily unavailable. Please retry later.',
      );
    }
  }

  return jsonResponse(
    {
      verdict: {
        status: 'approved',
        mediaType,
        objectPath,
        mimeType,
        byteSize,
        provider: verdict.provider,
        providerReference: verdict.providerReference ?? null,
        confidence: verdict.confidence ?? null,
        labels: verdict.labels ?? [],
      },
    },
    200,
  );
});

function resolveObjectPath(payload: ModerateUploadPayload): string | null {
  const objectPath = payload.objectPath?.trim();
  if (objectPath) {
    return objectPath;
  }

  const mediaUrl = payload.mediaUrl?.trim();
  if (!mediaUrl) {
    return null;
  }

  return extractMediaPath(mediaUrl);
}

function resolveMediaType(
  payload: ModerateUploadPayload,
  objectPath: string,
): MediaType | null {
  const provided = payload.mediaType;
  const inferred = inferMediaTypeFromPath(objectPath);

  if (!provided) {
    return inferred;
  }

  if (provided !== 'image' && provided !== 'video') {
    return null;
  }

  if (inferred && inferred !== provided) {
    return null;
  }

  return provided;
}

async function blobToBytes(fileBlob: Blob): Promise<Uint8Array | null> {
  try {
    const arrayBuffer = await fileBlob.arrayBuffer();
    return new Uint8Array(arrayBuffer);
  } catch (error) {
    console.error('moderate-upload blob read failed', error);
    return null;
  }
}

function evaluateBuiltinPolicy(
  mediaType: MediaType,
  mimeType: string | null,
  byteSize: number,
): PolicyVerdict {
  if (!mimeType) {
    return {
      status: 'blocked',
      provider: 'builtin',
      reason: 'Unsupported media format.',
    };
  }

  if (mediaType === 'image') {
    if (!allowedImageMimes.has(mimeType)) {
      return {
        status: 'blocked',
        provider: 'builtin',
        reason: 'Unsupported image type.',
      };
    }

    if (byteSize > maxImageBytes) {
      return {
        status: 'blocked',
        provider: 'builtin',
        reason: 'Image exceeds 8 MB upload limit.',
      };
    }
  }

  if (mediaType === 'video') {
    if (!allowedVideoMimes.has(mimeType)) {
      return {
        status: 'blocked',
        provider: 'builtin',
        reason: 'Unsupported video type.',
      };
    }

    if (byteSize > maxVideoBytes) {
      return {
        status: 'blocked',
        provider: 'builtin',
        reason: 'Video exceeds 10 MB upload limit.',
      };
    }
  }

  return {
    status: 'approved',
    provider: 'builtin',
    reason: null,
  };
}

function detectMimeType(bytes: Uint8Array, objectPath: string): string | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg';
  }

  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return 'image/png';
  }

  if (bytes.length >= 4 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) {
    return 'image/gif';
  }

  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return 'image/webp';
  }

  if (
    bytes.length >= 4 &&
    bytes[0] === 0x1a &&
    bytes[1] === 0x45 &&
    bytes[2] === 0xdf &&
    bytes[3] === 0xa3
  ) {
    return 'video/webm';
  }

  if (
    bytes.length >= 12 &&
    bytes[4] === 0x66 &&
    bytes[5] === 0x74 &&
    bytes[6] === 0x79 &&
    bytes[7] === 0x70
  ) {
    const brand = String.fromCharCode(bytes[8], bytes[9], bytes[10], bytes[11]);
    if (brand === 'qt  ') {
      return 'video/quicktime';
    }

    return 'video/mp4';
  }

  const lowerPath = objectPath.toLowerCase();
  if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lowerPath.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerPath.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lowerPath.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lowerPath.endsWith('.mov')) {
    return 'video/quicktime';
  }
  if (lowerPath.endsWith('.webm')) {
    return 'video/webm';
  }
  if (lowerPath.endsWith('.mp4') || lowerPath.endsWith('.m4v')) {
    return 'video/mp4';
  }

  return null;
}

async function runWebhookPolicyCheck(
  adminClient: SupabaseClient,
  userId: string,
  objectPath: string,
  mediaType: MediaType,
  mimeType: string | null,
  byteSize: number,
): Promise<PolicyVerdict | null> {
  const webhookUrl = Deno.env.get('UPLOAD_POLICY_WEBHOOK_URL')?.trim();
  if (!webhookUrl) {
    return null;
  }

  const strictMode = parseBoolean(Deno.env.get('UPLOAD_POLICY_STRICT_MODE'));

  let signedUrl: string | null = null;
  const { data: signedData, error: signedError } = await adminClient.storage
    .from('media')
    .createSignedUrl(objectPath, signedUrlTtlSeconds);

  if (!signedError && signedData?.signedUrl) {
    signedUrl = signedData.signedUrl;
  }

  const webhookToken = Deno.env.get('UPLOAD_POLICY_WEBHOOK_TOKEN')?.trim();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (webhookToken) {
    headers.Authorization = `Bearer ${webhookToken}`;
  }

  try {
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        userId,
        objectPath,
        mediaType,
        mimeType,
        byteSize,
        signedUrl,
      }),
    });

    if (!response.ok) {
      if (strictMode) {
        return {
          status: 'error',
          provider: 'webhook',
          reason: `webhook_http_${response.status}`,
        };
      }

      return {
        status: 'approved',
        provider: 'webhook_fallback',
        reason: `webhook_http_${response.status}`,
      };
    }

    const data = (await response.json()) as Record<string, unknown>;
    const decision = normalizeDecision(data.decision);

    if (!decision) {
      if (strictMode) {
        return {
          status: 'error',
          provider: 'webhook',
          reason: 'invalid_webhook_decision',
        };
      }

      return {
        status: 'approved',
        provider: 'webhook_fallback',
        reason: 'invalid_webhook_decision',
      };
    }

    const provider = normalizeString(data.provider) ?? 'webhook';
    const reason = normalizeString(data.reason);
    const confidence = normalizeNumber(data.confidence);
    const labels = normalizeLabels(data.labels);
    const providerReference = normalizeString(data.reference);

    if (decision === 'blocked') {
      return {
        status: 'blocked',
        provider,
        providerReference,
        reason: reason ?? 'Upload blocked by policy provider.',
        confidence,
        labels,
      };
    }

    return {
      status: 'approved',
      provider,
      providerReference,
      reason,
      confidence,
      labels,
    };
  } catch (error) {
    console.error('moderate-upload webhook request failed', error);

    if (strictMode) {
      return {
        status: 'error',
        provider: 'webhook',
        reason: 'webhook_request_failed',
      };
    }

    return {
      status: 'approved',
      provider: 'webhook_fallback',
      reason: 'webhook_request_failed',
    };
  }
}

function normalizeDecision(value: unknown): 'approved' | 'blocked' | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim().toLowerCase();
  if (normalized === 'allow' || normalized === 'approved' || normalized === 'pass') {
    return 'approved';
  }

  if (
    normalized === 'block' ||
    normalized === 'blocked' ||
    normalized === 'reject' ||
    normalized === 'denied' ||
    normalized === 'review'
  ) {
    return 'blocked';
  }

  return null;
}

function normalizeString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return null;
}

function normalizeLabels(value: unknown): string[] | null {
  if (!Array.isArray(value)) {
    return null;
  }

  const labels = value
    .map((item) => (typeof item === 'string' ? item.trim() : ''))
    .filter((item) => item.length > 0);

  return labels.length > 0 ? labels : null;
}

async function persistPolicyCheck(
  adminClient: SupabaseClient,
  userId: string,
  objectPath: string,
  mediaType: MediaType,
  mimeType: string | null,
  byteSize: number,
  verdict: PolicyVerdict,
): Promise<void> {
  const payload = {
    user_uuid: userId,
    object_path: objectPath,
    media_type: mediaType,
    mime_type: mimeType,
    byte_size: byteSize,
    status: verdict.status,
    provider: verdict.provider,
    provider_reference: verdict.providerReference ?? null,
    reason: verdict.reason ?? null,
    confidence: verdict.confidence ?? null,
    labels: verdict.labels ?? null,
    checked_at: new Date().toISOString(),
  };

  const { error } = await adminClient
    .from('media_policy_checks')
    .upsert(payload, { onConflict: 'object_path' });

  if (error) {
    console.error('moderate-upload policy persistence failed', error);
  }
}

async function removeMediaObject(
  adminClient: SupabaseClient,
  objectPath: string,
): Promise<void> {
  const { error } = await adminClient.storage.from('media').remove([objectPath]);
  if (error) {
    console.error('moderate-upload media removal failed', error);
  }
}

function parseBoolean(value: string | undefined): boolean {
  if (!value) {
    return false;
  }

  const normalized = value.trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes';
}
