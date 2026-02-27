import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ListSponsoredTemplatesPayload = {
  category?: string;
  limit?: number;
};

const allowedCategories = new Set<string>([
  'school',
  'workplace',
  'faith',
  'neighborhood',
  'other',
]);

const defaultLimit = 20;
const maxLimit = 50;

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'method_not_allowed', 'Use POST for this route.');
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');

  if (!supabaseUrl || !anonKey) {
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

  let payload: ListSponsoredTemplatesPayload;
  try {
    payload = (await req.json()) as ListSponsoredTemplatesPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const category = payload.category?.trim().toLowerCase() ?? null;
  if (category != null && !allowedCategories.has(category)) {
    return errorResponse(400, 'invalid_category', 'Unsupported category value.');
  }

  const limit = payload.limit ?? defaultLimit;
  if (!Number.isInteger(limit) || limit < 1 || limit > maxLimit) {
    return errorResponse(400, 'invalid_limit', `limit must be between 1 and ${maxLimit}.`);
  }

  let query = userClient
    .from('sponsored_community_templates')
    .select(
      'id, display_name, description, category, default_title, default_description, default_is_private, rules, created_at',
    )
    .eq('is_active', true)
    .order('created_at', { ascending: true })
    .limit(limit);

  if (category != null) {
    query = query.eq('category', category);
  }

  const { data: rows, error: queryError } = await query;

  if (queryError) {
    console.error('list-sponsored-community-templates query failed', queryError);
    return errorResponse(
      500,
      'templates_query_failed',
      'Unable to fetch sponsored community templates.',
    );
  }

  const templates = (rows ?? []).map((row) => {
    const rules = Array.isArray(row.rules)
      ? row.rules.filter((item): item is string => typeof item === 'string')
      : [];

    return {
      id: row.id,
      displayName: row.display_name,
      description: row.description,
      category: row.category,
      defaultTitle: row.default_title,
      defaultDescription: row.default_description,
      defaultIsPrivate: row.default_is_private,
      rules,
      createdAt: row.created_at,
    };
  });

  return jsonResponse({ templates }, 200);
});
