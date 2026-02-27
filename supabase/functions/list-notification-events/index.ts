import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';

type ListNotificationEventsPayload = {
  limit?: number;
  beforeCreatedAt?: string;
  eventType?: string;
};

const allowedEventTypes = new Set(['reply', 'reaction', 'challenge_entry', 'system']);
const defaultLimit = 30;
const maxLimit = 100;

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

  let payload: ListNotificationEventsPayload;
  try {
    payload = (await req.json()) as ListNotificationEventsPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const limit = payload.limit ?? defaultLimit;
  if (!Number.isInteger(limit) || limit < 1 || limit > maxLimit) {
    return errorResponse(400, 'invalid_limit', `limit must be between 1 and ${maxLimit}.`);
  }

  const eventType = payload.eventType?.trim().toLowerCase();
  if (eventType && !allowedEventTypes.has(eventType)) {
    return errorResponse(400, 'invalid_event_type', 'Unsupported eventType value.');
  }

  const beforeCreatedAt = payload.beforeCreatedAt?.trim();
  if (beforeCreatedAt && Number.isNaN(Date.parse(beforeCreatedAt))) {
    return errorResponse(
      400,
      'invalid_before_created_at',
      'beforeCreatedAt must be an ISO datetime string.',
    );
  }

  let query = userClient
    .from('notification_events')
    .select(
      'id, recipient_uuid, event_type, actor_uuid, post_id, reply_id, payload, created_at, delivered_at, delivery_attempts, last_error',
    )
    .eq('recipient_uuid', user.id)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (eventType) {
    query = query.eq('event_type', eventType);
  }

  if (beforeCreatedAt) {
    query = query.lt('created_at', beforeCreatedAt);
  }

  const { data: events, error: eventsError } = await query;

  if (eventsError) {
    console.error('list-notification-events query failed', eventsError);
    return errorResponse(
      500,
      'notification_events_query_failed',
      'Unable to fetch notification events.',
    );
  }

  const { count: undeliveredCount, error: countError } = await userClient
    .from('notification_events')
    .select('id', { count: 'exact', head: true })
    .eq('recipient_uuid', user.id)
    .is('delivered_at', null);

  if (countError) {
    console.error('list-notification-events count failed', countError);
    return errorResponse(
      500,
      'notification_events_count_failed',
      'Unable to fetch notification counters.',
    );
  }

  return jsonResponse(
    {
      events: (events ?? []).map((event) => ({
        id: event.id,
        recipientUuid: event.recipient_uuid,
        eventType: event.event_type,
        actorUuid: event.actor_uuid,
        postId: event.post_id,
        replyId: event.reply_id,
        payload: event.payload,
        createdAt: event.created_at,
        deliveredAt: event.delivered_at,
        deliveryAttempts: event.delivery_attempts,
        lastError: event.last_error,
      })),
      undeliveredCount: undeliveredCount ?? 0,
    },
    200,
  );
});
