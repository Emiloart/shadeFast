import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ListFeatureFlagsPayload = {
  includeDisabled?: boolean;
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

  let payload: ListFeatureFlagsPayload;
  try {
    payload = (await req.json()) as ListFeatureFlagsPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const includeDisabled = payload.includeDisabled ?? true;
  if (typeof includeDisabled !== 'boolean') {
    return errorResponse(400, 'invalid_include_disabled', 'includeDisabled must be boolean.');
  }

  const { data: rows, error: flagsError } = await userClient.rpc('resolve_feature_flags', {
    target_user: user.id,
  });

  if (flagsError) {
    console.error('list-feature-flags rpc failed', flagsError);
    return errorResponse(500, 'feature_flags_lookup_failed', 'Unable to resolve feature flags.');
  }

  const flags = Array.isArray(rows)
    ? rows
        .map((row) => {
          if (typeof row !== 'object' || row === null) {
            return null;
          }

          const value = row as Record<string, unknown>;
          return {
            id: String(value.id ?? ''),
            enabled: value.enabled === true,
            rolloutPercentage: Number(value.rollout_percentage ?? 0),
            config: typeof value.config === 'object' && value.config !== null
              ? value.config
              : {},
          };
        })
        .filter((row): row is {
          id: string;
          enabled: boolean;
          rolloutPercentage: number;
          config: unknown;
        } => row !== null && row.id.length > 0)
    : [];

  const filtered = includeDisabled ? flags : flags.filter((flag) => flag.enabled);

  return jsonResponse({ flags: filtered }, 200);
});
