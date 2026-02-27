import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type JoinCommunityPayload = {
  joinCode?: string;
  communityId?: string;
};

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

  let payload: JoinCommunityPayload;
  try {
    payload = (await req.json()) as JoinCommunityPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const joinCode = payload.joinCode?.trim().toUpperCase();
  const communityId = payload.communityId?.trim();

  if (!joinCode && !communityId) {
    return errorResponse(
      400,
      'missing_locator',
      'Provide joinCode or communityId.',
    );
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const query = adminClient
    .from('communities')
    .select('id, name, description, category, is_private, join_code, creator_uuid, created_at')
    .limit(1);

  const { data: community, error: communityError } = await (joinCode
    ? query.eq('join_code', joinCode).maybeSingle()
    : query.eq('id', communityId).maybeSingle());

  if (communityError) {
    console.error('join-community lookup failed', communityError);
    return errorResponse(
      500,
      'community_lookup_failed',
      'Could not resolve community.',
    );
  }

  if (!community) {
    return errorResponse(404, 'community_not_found', 'Community not found.');
  }

  if (community.is_private && !joinCode && community.creator_uuid !== user.id) {
    return errorResponse(
      403,
      'join_code_required',
      'Private communities require a join code.',
    );
  }

  const { data: membership, error: membershipError } = await adminClient
    .from('community_memberships')
    .upsert(
      {
        community_id: community.id,
        user_uuid: user.id,
        role: 'member',
      },
      {
        onConflict: 'community_id,user_uuid',
        ignoreDuplicates: true,
      },
    )
    .select('id, role, created_at')
    .maybeSingle();

  if (membershipError) {
    console.error('join-community membership failed', membershipError);
    return errorResponse(
      500,
      'membership_create_failed',
      'Could not add membership.',
    );
  }

  return jsonResponse(
    {
      community: {
        id: community.id,
        name: community.name,
        description: community.description,
        category: community.category,
        is_private: community.is_private,
        join_code: community.join_code,
        created_at: community.created_at,
      },
      membership,
    },
    200,
  );
});
