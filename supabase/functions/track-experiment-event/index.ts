import { createClient } from '@supabase/supabase-js';

import { isUserBanned } from '../_shared/enforcement.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import { checkAndBumpRateLimit } from '../_shared/rate_limit.ts';

type TrackExperimentEventPayload = {
  eventName?: string;
  properties?: Record<string, unknown>;
  appVersion?: string;
  platform?: string;
};

const eventNamePattern = /^[a-z0-9][a-z0-9_.-]{1,63}$/i;
const allowedPlatforms = new Set<string>(['ios', 'android', 'web', 'unknown', 'mobile']);

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

  let payload: TrackExperimentEventPayload;
  try {
    payload = (await req.json()) as TrackExperimentEventPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const eventName = payload.eventName?.trim().toLowerCase() ?? '';
  if (!eventNamePattern.test(eventName)) {
    return errorResponse(400, 'invalid_event_name', 'eventName format is invalid.');
  }

  const properties = payload.properties;
  if (properties != null && (typeof properties !== 'object' || Array.isArray(properties))) {
    return errorResponse(400, 'invalid_properties', 'properties must be an object when provided.');
  }

  const appVersionRaw = payload.appVersion?.trim() ?? '';
  if (appVersionRaw.length > 40) {
    return errorResponse(400, 'invalid_app_version', 'appVersion must be 40 chars or fewer.');
  }
  const appVersion = appVersionRaw.length > 0 ? appVersionRaw : null;

  const platformRaw = payload.platform?.trim().toLowerCase() ?? 'unknown';
  if (!allowedPlatforms.has(platformRaw)) {
    return errorResponse(400, 'invalid_platform', 'Unsupported platform value.');
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
      return errorResponse(403, 'banned_user', 'This anonymous user is currently restricted.');
    }
  } catch (enforcementError) {
    console.error('track-experiment-event enforcement check failed', enforcementError);
    return errorResponse(500, 'enforcement_check_failed', 'Unable to validate enforcement status.');
  }

  try {
    const limit = await checkAndBumpRateLimit(
      adminClient,
      user.id,
      'track_experiment_event_1h',
      60 * 60,
      240,
    );
    if (!limit.allowed) {
      return errorResponse(429, 'rate_limited', 'Too many events submitted recently.');
    }
  } catch (rateError) {
    console.error('track-experiment-event rate limit check failed', rateError);
    return errorResponse(500, 'rate_limit_check_failed', 'Unable to validate event submission limits.');
  }

  const { data: eventRow, error: insertError } = await adminClient
    .from('experiment_events')
    .insert({
      user_uuid: user.id,
      event_name: eventName,
      event_properties: properties ?? {},
      app_version: appVersion,
      platform: platformRaw,
    })
    .select('id, created_at')
    .single();

  if (insertError || !eventRow) {
    console.error('track-experiment-event insert failed', insertError);
    return errorResponse(500, 'event_insert_failed', 'Unable to record experiment event.');
  }

  return jsonResponse(
    {
      ok: true,
      event: {
        id: eventRow.id,
        eventName,
        createdAt: eventRow.created_at,
      },
    },
    201,
  );
});
