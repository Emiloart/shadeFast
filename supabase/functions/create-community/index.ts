import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type CreateCommunityPayload = {
  name?: string;
  description?: string;
  category?: string;
  isPrivate?: boolean;
  templateId?: string;
};

const allowedCategories = new Set<string>([
  'school',
  'workplace',
  'faith',
  'neighborhood',
  'other',
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

  let payload: CreateCommunityPayload;
  try {
    payload = (await req.json()) as CreateCommunityPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const templateId = payload.templateId?.trim() || null;
  let template:
    | {
        id: string;
        category: string;
        default_title: string;
        default_description: string | null;
        default_is_private: boolean;
      }
    | null = null;

  if (templateId != null) {
    const { data: templateRow, error: templateError } = await adminClient
      .from('sponsored_community_templates')
      .select(
        'id, category, default_title, default_description, default_is_private',
      )
      .eq('id', templateId)
      .eq('is_active', true)
      .maybeSingle();

    if (templateError) {
      console.error('create-community template lookup failed', templateError);
      return errorResponse(
        500,
        'template_lookup_failed',
        'Unable to validate sponsored template.',
      );
    }

    if (!templateRow) {
      return errorResponse(
        404,
        'template_not_found',
        'Sponsored template was not found or is inactive.',
      );
    }

    template = templateRow;
  }

  const name = ((payload.name ?? '').trim() || template?.default_title || '').trim();
  if (name.length < 2 || name.length > 80) {
    return errorResponse(
      400,
      'invalid_name',
      'Community name must be between 2 and 80 characters.',
    );
  }

  const description = ((payload.description?.trim() || template?.default_description || '')
    .trim() || null);
  if (description && description.length > 500) {
    return errorResponse(
      400,
      'invalid_description',
      'Description must be 500 characters or fewer.',
    );
  }

  const normalizedCategory =
    (payload.category?.trim() || template?.category || 'other').toLowerCase();
  if (!allowedCategories.has(normalizedCategory)) {
    return errorResponse(400, 'invalid_category', 'Unsupported category value.');
  }

  const isPrivate = payload.isPrivate ?? template?.default_is_private ?? false;

  for (let attempt = 0; attempt < 12; attempt += 1) {
    const joinCode = createJoinCode(8);

    const { data: community, error: insertError } = await adminClient
      .from('communities')
      .insert({
        name,
        description,
        category: normalizedCategory,
        join_code: joinCode,
        is_private: isPrivate,
        creator_uuid: user.id,
        sponsored_template_id: template?.id ?? null,
      })
      .select('id, name, description, category, is_private, join_code, created_at')
      .single();

    if (insertError) {
      if (insertError.code === '23505') {
        continue;
      }

      console.error('create-community insert failed', insertError);
      return errorResponse(
        500,
        'community_create_failed',
        'Unable to create community.',
      );
    }

    const { error: memberError } = await adminClient
      .from('community_memberships')
      .insert({
        community_id: community.id,
        user_uuid: user.id,
        role: 'owner',
      });

    if (memberError) {
      console.error('create-community membership failed', memberError);
      await adminClient.from('communities').delete().eq('id', community.id);
      return errorResponse(
        500,
        'community_membership_failed',
        'Unable to assign owner membership.',
      );
    }

    return jsonResponse(
      {
        community,
      },
      201,
    );
  }

  return errorResponse(
    500,
    'join_code_generation_failed',
    'Could not allocate a unique join code.',
  );
});

function createJoinCode(length: number): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(length));

  return Array.from(bytes)
    .map((byte) => alphabet[byte % alphabet.length])
    .join('');
}
