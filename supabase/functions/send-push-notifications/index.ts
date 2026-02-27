import { createClient } from '@supabase/supabase-js';

import { corsHeaders, errorResponse, jsonResponse } from '../_shared/http.ts';
import {
  buildNotificationText,
  parseBoolean,
  type NotificationEventRow,
} from '../_shared/push.ts';

type SendPushNotificationsPayload = {
  limit?: number;
  dryRun?: boolean;
};

type PushTokenRow = {
  id: string;
  user_uuid: string;
  token: string;
  platform: 'ios' | 'android' | 'web';
};

const defaultLimit = 200;
const maxLimit = 500;

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'method_not_allowed', 'Use POST for this route.');
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    return errorResponse(500, 'misconfigured_env', 'Missing function secrets.');
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const expected = `Bearer ${serviceRoleKey}`;
  if (authHeader.trim() !== expected) {
    return errorResponse(401, 'invalid_auth', 'Service role authorization required.');
  }

  let payload: SendPushNotificationsPayload;
  try {
    payload = (await req.json()) as SendPushNotificationsPayload;
  } catch (_) {
    return errorResponse(400, 'invalid_json', 'Invalid JSON payload.');
  }

  const limit = payload.limit ?? defaultLimit;
  if (!Number.isInteger(limit) || limit < 1 || limit > maxLimit) {
    return errorResponse(400, 'invalid_limit', `limit must be between 1 and ${maxLimit}.`);
  }

  const dryRun = payload.dryRun ?? false;
  if (typeof dryRun !== 'boolean') {
    return errorResponse(400, 'invalid_dry_run', 'dryRun must be boolean.');
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: rows, error: rowsError } = await adminClient
    .from('notification_events')
    .select(
      'id, recipient_uuid, event_type, actor_uuid, post_id, reply_id, payload, created_at, delivered_at, delivery_attempts, last_error',
    )
    .is('delivered_at', null)
    .order('created_at', { ascending: true })
    .limit(limit);

  if (rowsError) {
    console.error('send-push-notifications queue lookup failed', rowsError);
    return errorResponse(500, 'notification_queue_lookup_failed', 'Unable to fetch notification queue.');
  }

  const events = (rows ?? []) as NotificationEventRow[];
  if (events.length === 0) {
    return jsonResponse(
      {
        queued: 0,
        processed: 0,
        delivered: 0,
        failed: 0,
      },
      200,
    );
  }

  const recipientIds = Array.from(new Set(events.map((event) => event.recipient_uuid)));

  const { data: tokenRows, error: tokenError } = await adminClient
    .from('push_tokens')
    .select('id, user_uuid, token, platform')
    .in('user_uuid', recipientIds)
    .is('revoked_at', null)
    .order('last_seen_at', { ascending: false });

  if (tokenError) {
    console.error('send-push-notifications token lookup failed', tokenError);
    return errorResponse(500, 'push_token_lookup_failed', 'Unable to fetch active push tokens.');
  }

  const tokensByRecipient = groupTokensByRecipient((tokenRows ?? []) as PushTokenRow[]);

  const webhookUrl = Deno.env.get('PUSH_PROVIDER_WEBHOOK_URL')?.trim();
  const webhookToken = Deno.env.get('PUSH_PROVIDER_WEBHOOK_TOKEN')?.trim();
  const strictMode = parseBoolean(Deno.env.get('PUSH_PROVIDER_STRICT_MODE'));

  if (!dryRun && !webhookUrl) {
    return errorResponse(
      500,
      'missing_push_provider',
      'PUSH_PROVIDER_WEBHOOK_URL is required for push delivery.',
    );
  }

  let processed = 0;
  let delivered = 0;
  let failed = 0;

  for (const event of events) {
    processed += 1;

    const tokens = tokensByRecipient.get(event.recipient_uuid) ?? [];
    if (tokens.length === 0) {
      if (!dryRun) {
        await markDelivered(adminClient, event, 'no_active_tokens');
      }
      delivered += 1;
      continue;
    }

    if (dryRun) {
      delivered += 1;
      continue;
    }

    const pushText = buildNotificationText(event);
    let successCount = 0;
    const tokenErrors: string[] = [];
    const revokeTokenIds: string[] = [];

    for (const token of tokens) {
      const delivery = await deliverToToken({
        webhookUrl: webhookUrl!,
        webhookToken,
        event,
        token,
        pushText,
      });

      if (delivery.ok) {
        successCount += 1;
        continue;
      }

      tokenErrors.push(`${token.platform}:${delivery.error}`);
      if (delivery.shouldRevokeToken) {
        revokeTokenIds.push(token.id);
      }
    }

    if (revokeTokenIds.length > 0) {
      const { error: revokeError } = await adminClient
        .from('push_tokens')
        .update({ revoked_at: new Date().toISOString() })
        .in('id', revokeTokenIds);

      if (revokeError) {
        console.error('send-push-notifications token revoke failed', revokeError);
      }
    }

    if (successCount > 0) {
      await markDelivered(
        adminClient,
        event,
        tokenErrors.length > 0 ? truncateError(tokenErrors.join('; ')) : null,
      );
      delivered += 1;
      continue;
    }

    const updateError = truncateError(
      tokenErrors.length > 0 ? tokenErrors.join('; ') : 'provider_unavailable',
    );

    if (strictMode) {
      const { error: failUpdateError } = await adminClient
        .from('notification_events')
        .update({
          delivery_attempts: event.delivery_attempts + 1,
          last_error: updateError,
        })
        .eq('id', event.id);

      if (failUpdateError) {
        console.error('send-push-notifications strict failure update failed', failUpdateError);
      }
    } else {
      await markDelivered(adminClient, event, updateError);
      delivered += 1;
      continue;
    }

    failed += 1;
  }

  return jsonResponse(
    {
      queued: events.length,
      processed,
      delivered,
      failed,
      dryRun,
    },
    200,
  );
});

function groupTokensByRecipient(rows: PushTokenRow[]): Map<string, PushTokenRow[]> {
  const grouped = new Map<string, PushTokenRow[]>();

  for (const row of rows) {
    const existing = grouped.get(row.user_uuid);
    if (existing) {
      existing.push(row);
    } else {
      grouped.set(row.user_uuid, [row]);
    }
  }

  return grouped;
}

async function markDelivered(
  adminClient: ReturnType<typeof createClient>,
  event: NotificationEventRow,
  lastError: string | null,
): Promise<void> {
  const { error } = await adminClient
    .from('notification_events')
    .update({
      delivered_at: new Date().toISOString(),
      delivery_attempts: event.delivery_attempts + 1,
      last_error: lastError,
    })
    .eq('id', event.id);

  if (error) {
    console.error('send-push-notifications delivered update failed', error);
  }
}

async function deliverToToken(input: {
  webhookUrl: string;
  webhookToken?: string;
  event: NotificationEventRow;
  token: PushTokenRow;
  pushText: ReturnType<typeof buildNotificationText>;
}): Promise<{ ok: boolean; error: string; shouldRevokeToken: boolean }> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (input.webhookToken) {
    headers.Authorization = `Bearer ${input.webhookToken}`;
  }

  try {
    const response = await fetch(input.webhookUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        eventId: input.event.id,
        eventType: input.event.event_type,
        recipientUuid: input.event.recipient_uuid,
        actorUuid: input.event.actor_uuid,
        postId: input.event.post_id,
        replyId: input.event.reply_id,
        payload: input.event.payload ?? {},
        createdAt: input.event.created_at,
        token: {
          value: input.token.token,
          platform: input.token.platform,
        },
        notification: {
          title: input.pushText.title,
          body: input.pushText.body,
          data: input.pushText.data,
        },
      }),
    });

    if (response.ok) {
      return { ok: true, error: '', shouldRevokeToken: false };
    }

    const responseText = await safeResponseText(response);
    const shouldRevoke = shouldRevokeFromResponse(response.status, responseText);

    return {
      ok: false,
      error: `http_${response.status}`,
      shouldRevokeToken: shouldRevoke,
    };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : 'request_failed',
      shouldRevokeToken: false,
    };
  }
}

function shouldRevokeFromResponse(status: number, responseText: string): boolean {
  if (status === 404 || status === 410) {
    return true;
  }

  if (status !== 400) {
    return false;
  }

  const normalized = responseText.toLowerCase();
  return (
    normalized.includes('invalid_token') ||
    normalized.includes('notregistered') ||
    normalized.includes('unregistered')
  );
}

async function safeResponseText(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch (_) {
    return '';
  }
}

function truncateError(value: string, maxLength = 500): string {
  const trimmed = value.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }

  return `${trimmed.substring(0, maxLength - 3)}...`;
}
