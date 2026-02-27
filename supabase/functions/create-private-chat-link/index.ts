import { createClient } from '@supabase/supabase-js';

import { hasAnyPremiumEntitlement } from '../_shared/entitlements.ts';
import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type CreatePrivateChatPayload = {
  readOnce?: boolean;
  ttlMinutes?: number;
};

const minTtlMinutes = 5;
const maxTtlMinutes = 60;
const defaultTtlMinutes = 60;
const freeDailyPrivateLinkLimit = 5;

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

  let payload: CreatePrivateChatPayload;
  try {
    payload = (await req.json()) as CreatePrivateChatPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const readOnce = payload.readOnce ?? false;
  if (typeof readOnce !== 'boolean') {
    return errorResponse(400, 'invalid_read_once', 'readOnce must be boolean.');
  }

  const ttlMinutesRaw = payload.ttlMinutes ?? defaultTtlMinutes;
  if (
    !Number.isInteger(ttlMinutesRaw) ||
    ttlMinutesRaw < minTtlMinutes ||
    ttlMinutesRaw > maxTtlMinutes
  ) {
    return errorResponse(
      400,
      'invalid_ttl',
      `ttlMinutes must be between ${minTtlMinutes} and ${maxTtlMinutes}.`,
    );
  }

  const token = crypto
    .randomUUID()
    .replaceAll('-', '')
    .slice(0, 16)
    .toUpperCase();
  const expiresAt = new Date(Date.now() + ttlMinutesRaw * 60 * 1000).toISOString();

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
        'This anonymous user is currently restricted from private links.',
      );
    }
  } catch (enforcementError) {
    console.error(
      'create-private-chat-link enforcement check failed',
      enforcementError,
    );
    return errorResponse(
      500,
      'enforcement_check_failed',
      'Unable to validate enforcement status.',
    );
  }

  let isPremium = false;
  try {
    isPremium = await hasAnyPremiumEntitlement(adminClient, user.id);
  } catch (entitlementError) {
    console.error(
      'create-private-chat-link entitlement check failed',
      entitlementError,
    );
    return errorResponse(
      500,
      'entitlement_check_failed',
      'Unable to validate premium entitlement status.',
    );
  }

  if (!isPremium) {
    const windowStart = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { count: linkCount, error: linkCountError } = await adminClient
      .from('private_chats')
      .select('id', { count: 'exact', head: true })
      .eq('creator_uuid', user.id)
      .gte('created_at', windowStart);

    if (linkCountError) {
      console.error(
        'create-private-chat-link quota check failed',
        linkCountError,
      );
      return errorResponse(
        500,
        'private_link_quota_check_failed',
        'Unable to validate daily private link quota.',
      );
    }

    if ((linkCount ?? 0) >= freeDailyPrivateLinkLimit) {
      return errorResponse(
        403,
        'premium_required',
        `Free users can create up to ${freeDailyPrivateLinkLimit} private links per 24 hours. Upgrade to premium for higher limits.`,
      );
    }
  }

  try {
    const rateLimitKey = isPremium
      ? 'create_private_chat_1h_premium'
      : 'create_private_chat_1h';
    const maxLinksPerHour = isPremium ? 120 : 20;
    const limit = await checkAndBumpRateLimit(
      adminClient,
      user.id,
      rateLimitKey,
      60 * 60,
      maxLinksPerHour,
    );
    if (!limit.allowed) {
      return errorResponse(
        429,
        'rate_limited',
        'Too many private links created recently. Please wait and retry.',
      );
    }
  } catch (rateError) {
    console.error('create-private-chat-link rate limit check failed', rateError);
    return errorResponse(
      500,
      'rate_limit_check_failed',
      'Unable to validate link creation limits.',
    );
  }

  const { data: chat, error: chatError } = await adminClient
    .from('private_chats')
    .insert({
      link_token: token,
      creator_uuid: user.id,
      read_once: readOnce,
      expires_at: expiresAt,
    })
    .select('id, link_token, read_once, expires_at')
    .single();

  if (chatError || !chat) {
    if (chatError) {
      console.error('create-private-chat-link create chat failed', chatError);
    }
    return errorResponse(500, 'chat_create_failed', 'Failed to create private chat.');
  }

  const { error: participantError } = await adminClient
    .from('private_chat_participants')
    .upsert(
      {
        private_chat_id: chat.id,
        user_uuid: user.id,
      },
      {
        onConflict: 'private_chat_id,user_uuid',
      },
    );

  if (participantError) {
    console.error(
      'create-private-chat-link participant upsert failed',
      participantError,
    );
    return errorResponse(
      500,
      'participant_create_failed',
      'Failed to create chat participant.',
    );
  }

  return jsonResponse(
    {
      chat: {
        id: chat.id,
        token: chat.link_token,
        readOnce: chat.read_once,
        expiresAt: chat.expires_at,
      },
      entitlement: {
        isPremium,
      },
      links: {
        app: `shadefast://app/chat/${chat.link_token}`,
        web: `https://shadefast.io/chat/${chat.link_token}`,
      },
    },
    201,
  );
});
