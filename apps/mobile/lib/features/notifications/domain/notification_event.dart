class NotificationEvent {
  const NotificationEvent({
    required this.id,
    required this.recipientUuid,
    required this.eventType,
    required this.createdAt,
    this.actorUuid,
    this.postId,
    this.replyId,
    this.payload,
    this.deliveredAt,
    this.deliveryAttempts = 0,
    this.lastError,
  });

  final String id;
  final String recipientUuid;
  final String eventType;
  final String? actorUuid;
  final String? postId;
  final String? replyId;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final int deliveryAttempts;
  final String? lastError;

  factory NotificationEvent.fromMap(Map<String, dynamic> map) {
    return NotificationEvent(
      id: map['id'] as String,
      recipientUuid: map['recipientUuid'] as String,
      eventType: map['eventType'] as String? ?? 'system',
      actorUuid: map['actorUuid'] as String?,
      postId: map['postId'] as String?,
      replyId: map['replyId'] as String?,
      payload: map['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      deliveredAt: map['deliveredAt'] is String
          ? DateTime.tryParse(map['deliveredAt'] as String)
          : null,
      deliveryAttempts: _asInt(map['deliveryAttempts']),
      lastError: map['lastError'] as String?,
    );
  }
}

class NotificationFeedPage {
  const NotificationFeedPage({
    required this.events,
    required this.undeliveredCount,
  });

  final List<NotificationEvent> events;
  final int undeliveredCount;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}
