export type NotificationEventType =
  | 'reply'
  | 'reaction'
  | 'challenge_entry'
  | 'system';

export type NotificationEventRow = {
  id: string;
  recipient_uuid: string;
  event_type: NotificationEventType;
  actor_uuid: string | null;
  post_id: string | null;
  reply_id: string | null;
  payload: Record<string, unknown> | null;
  created_at: string;
  delivered_at: string | null;
  delivery_attempts: number;
  last_error: string | null;
};

export function buildNotificationText(event: NotificationEventRow): {
  title: string;
  body: string;
  data: Record<string, string>;
} {
  switch (event.event_type) {
    case 'reply': {
      const preview = normalizePreview(event.payload?.preview);
      return {
        title: 'New reply',
        body: preview ? `Someone replied: ${preview}` : 'Someone replied to your post.',
        data: {
          eventType: event.event_type,
          postId: event.post_id ?? '',
          replyId: event.reply_id ?? '',
          eventId: event.id,
        },
      };
    }

    case 'reaction': {
      return {
        title: 'New reaction',
        body: 'Someone reacted to your post.',
        data: {
          eventType: event.event_type,
          postId: event.post_id ?? '',
          eventId: event.id,
        },
      };
    }

    case 'challenge_entry': {
      return {
        title: 'Challenge update',
        body: 'A new entry was submitted to your challenge.',
        data: {
          eventType: event.event_type,
          postId: event.post_id ?? '',
          challengeId: asString(event.payload?.challengeId) ?? '',
          eventId: event.id,
        },
      };
    }

    case 'system':
    default: {
      return {
        title: asString(event.payload?.title) ?? 'ShadeFast',
        body: asString(event.payload?.body) ?? 'You have a new notification.',
        data: {
          eventType: event.event_type,
          eventId: event.id,
        },
      };
    }
  }
}

export function parseBoolean(value: string | undefined): boolean {
  if (!value) {
    return false;
  }

  const normalized = value.trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes';
}

function normalizePreview(value: unknown): string | null {
  const raw = asString(value);
  if (!raw) {
    return null;
  }

  return raw.length > 120 ? `${raw.substring(0, 120)}...` : raw;
}

function asString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
