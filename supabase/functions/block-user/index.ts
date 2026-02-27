import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type BlockPayload = {
  blockedUserId?: string;
  action?: 'add' | 'remove';
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

  let payload: BlockPayload;
  try {
    payload = (await req.json()) as BlockPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const blockedUserId = payload.blockedUserId?.trim();
  if (!blockedUserId || !uuidPattern.test(blockedUserId)) {
    return errorResponse(
      400,
      'invalid_blocked_user',
      'blockedUserId must be a valid UUID.',
    );
  }

  if (blockedUserId === user.id) {
    return errorResponse(400, 'cannot_block_self', 'Cannot block your own user id.');
  }

  const action = payload.action ?? 'add';
  if (action !== 'add' && action !== 'remove') {
    return errorResponse(400, 'invalid_action', 'Action must be add or remove.');
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  if (action === 'add') {
    const { error } = await adminClient.from('blocks').upsert(
      {
        blocker_uuid: user.id,
        blocked_uuid: blockedUserId,
      },
      {
        onConflict: 'blocker_uuid,blocked_uuid',
      },
    );

    if (error) {
      console.error('block-user insert failed', error);
      return errorResponse(500, 'block_insert_failed', 'Failed to block user.');
    }
  } else {
    const { error } = await adminClient
      .from('blocks')
      .delete()
      .eq('blocker_uuid', user.id)
      .eq('blocked_uuid', blockedUserId);

    if (error) {
      console.error('block-user delete failed', error);
      return errorResponse(500, 'block_delete_failed', 'Failed to unblock user.');
    }
  }

  return jsonResponse(
    {
      blocked: action === 'add',
      blockedUserId,
    },
    200,
  );
});
