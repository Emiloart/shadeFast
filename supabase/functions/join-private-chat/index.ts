import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type JoinPrivateChatPayload = {
  token?: string;
};

const tokenPattern = /^[A-Z0-9]{8,32}$/;

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

  let payload: JoinPrivateChatPayload;
  try {
    payload = (await req.json()) as JoinPrivateChatPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const token = payload.token?.trim().toUpperCase();
  if (!token || !tokenPattern.test(token)) {
    return errorResponse(400, 'invalid_token', 'token must be 8-32 uppercase chars.');
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
        'This anonymous user is currently restricted from joining private chats.',
      );
    }
  } catch (enforcementError) {
    console.error('join-private-chat enforcement check failed', enforcementError);
    return errorResponse(
      500,
      'enforcement_check_failed',
      'Unable to validate enforcement status.',
    );
  }

  const { data: chat, error: chatError } = await adminClient
    .from('private_chats')
    .select('id, link_token, read_once, expires_at')
    .eq('link_token', token)
    .maybeSingle();

  if (chatError) {
    console.error('join-private-chat lookup failed', chatError);
    return errorResponse(500, 'chat_lookup_failed', 'Failed to lookup chat.');
  }

  if (!chat) {
    return errorResponse(404, 'chat_not_found', 'Private chat link not found.');
  }

  if (new Date(chat.expires_at).getTime() <= Date.now()) {
    return errorResponse(410, 'chat_expired', 'This private chat link has expired.');
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
    console.error('join-private-chat participant upsert failed', participantError);
    return errorResponse(
      500,
      'participant_create_failed',
      'Failed to join private chat.',
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
    },
    200,
  );
});
