import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ReactPayload = {
  postId?: string;
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

  let payload: ReactPayload;
  try {
    payload = (await req.json()) as ReactPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const postId = payload.postId?.trim();
  if (!postId || !uuidPattern.test(postId)) {
    return errorResponse(400, 'invalid_post_id', 'postId must be a valid UUID.');
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

  const { data: post, error: postError } = await adminClient
    .from('posts')
    .select('id, community_id, expires_at')
    .eq('id', postId)
    .maybeSingle();

  if (postError) {
    console.error('react-to-post lookup failed', postError);
    return errorResponse(500, 'post_lookup_failed', 'Could not lookup post.');
  }

  if (!post) {
    return errorResponse(404, 'post_not_found', 'Post not found.');
  }

  if (new Date(post.expires_at).getTime() <= Date.now()) {
    return errorResponse(410, 'post_expired', 'Post has already expired.');
  }

  if (post.community_id) {
    const { data: community, error: communityError } = await adminClient
      .from('communities')
      .select('id, is_private, creator_uuid')
      .eq('id', post.community_id)
      .maybeSingle();

    if (communityError) {
      console.error('react-to-post community lookup failed', communityError);
      return errorResponse(
        500,
        'community_lookup_failed',
        'Could not verify community access.',
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
        console.error('react-to-post membership lookup failed', membershipError);
        return errorResponse(
          500,
          'membership_lookup_failed',
          'Could not verify membership.',
        );
      }

      if (!membership) {
        return errorResponse(
          403,
          'membership_required',
          'You cannot react in this private community.',
        );
      }
    }
  }

  if (action === 'add') {
    const { error: insertError } = await adminClient.from('reactions').insert({
      post_id: post.id,
      user_uuid: user.id,
      kind: 'heart',
    });

    if (insertError && insertError.code !== '23505') {
      console.error('react-to-post insert failed', insertError);
      return errorResponse(500, 'reaction_add_failed', 'Could not add reaction.');
    }
  } else {
    const { error: deleteError } = await adminClient
      .from('reactions')
      .delete()
      .eq('post_id', post.id)
      .eq('user_uuid', user.id)
      .eq('kind', 'heart');

    if (deleteError) {
      console.error('react-to-post delete failed', deleteError);
      return errorResponse(
        500,
        'reaction_remove_failed',
        'Could not remove reaction.',
      );
    }
  }

  const { count, error: countError } = await adminClient
    .from('reactions')
    .select('id', { count: 'exact', head: true })
    .eq('post_id', post.id)
    .eq('kind', 'heart');

  if (countError) {
    console.error('react-to-post count failed', countError);
    return errorResponse(500, 'reaction_count_failed', 'Could not update counts.');
  }

  const likeCount = count ?? 0;

  const { error: postUpdateError } = await adminClient
    .from('posts')
    .update({ like_count: likeCount })
    .eq('id', post.id);

  if (postUpdateError) {
    console.error('react-to-post update post failed', postUpdateError);
    return errorResponse(500, 'post_update_failed', 'Could not update post count.');
  }

  return jsonResponse(
    {
      postId: post.id,
      likeCount,
      liked: action === 'add',
    },
    200,
  );
});
