import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ReadPrivateMessagePayload = {
  privateChatId?: string;
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

  let payload: ReadPrivateMessagePayload;
  try {
    payload = (await req.json()) as ReadPrivateMessagePayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const privateChatId = payload.privateChatId?.trim();
  if (!privateChatId || !uuidPattern.test(privateChatId)) {
    return errorResponse(
      400,
      'invalid_private_chat_id',
      'privateChatId must be a valid UUID.',
    );
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: chat, error: chatError } = await adminClient
    .from('private_chats')
    .select('id, read_once, expires_at')
    .eq('id', privateChatId)
    .maybeSingle();

  if (chatError) {
    console.error('read-private-message-once chat lookup failed', chatError);
    return errorResponse(500, 'chat_lookup_failed', 'Failed to lookup chat.');
  }

  if (!chat) {
    return errorResponse(404, 'chat_not_found', 'Private chat not found.');
  }

  if (new Date(chat.expires_at).getTime() <= Date.now()) {
    return errorResponse(410, 'chat_expired', 'Private chat has expired.');
  }

  if (!chat.read_once) {
    return errorResponse(
      400,
      'chat_not_read_once',
      'Chat is not configured for read-once messages.',
    );
  }

  const { data: membership, error: membershipError } = await adminClient
    .from('private_chat_participants')
    .select('id')
    .eq('private_chat_id', chat.id)
    .eq('user_uuid', user.id)
    .maybeSingle();

  if (membershipError) {
    console.error(
      'read-private-message-once membership lookup failed',
      membershipError,
    );
    return errorResponse(
      500,
      'membership_lookup_failed',
      'Failed to validate participant.',
    );
  }

  if (!membership) {
    return errorResponse(
      403,
      'participant_required',
      'You are not a participant of this chat.',
    );
  }

  const { data: messages, error: messagesError } = await adminClient
    .from('chat_messages')
    .select('id, private_chat_id, sender_uuid, body, created_at, expires_at')
    .eq('private_chat_id', chat.id)
    .neq('sender_uuid', user.id)
    .order('created_at', { ascending: true })
    .limit(100);

  if (messagesError) {
    console.error('read-private-message-once message lookup failed', messagesError);
    return errorResponse(500, 'message_lookup_failed', 'Failed to read messages.');
  }

  const rows = messages ?? [];
  if (rows.length == 0) {
    return jsonResponse(
      {
        messages: [],
      },
      200,
    );
  }

  const ids = rows.map((row) => row.id);
  const { error: deleteError } = await adminClient
    .from('chat_messages')
    .delete()
    .in('id', ids);

  if (deleteError) {
    console.error('read-private-message-once delete failed', deleteError);
    return errorResponse(
      500,
      'message_delete_failed',
      'Failed to consume read-once messages.',
    );
  }

  return jsonResponse(
    {
      messages: rows,
    },
    200,
  );
});
