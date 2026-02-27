class PrivateChatSession {
  const PrivateChatSession({
    required this.id,
    required this.token,
    required this.readOnce,
    required this.expiresAt,
  });

  final String id;
  final String token;
  final bool readOnce;
  final String expiresAt;

  factory PrivateChatSession.fromMap(Map<String, dynamic> map) {
    return PrivateChatSession(
      id: map['id'] as String,
      token: map['token'] as String,
      readOnce: map['readOnce'] as bool? ?? false,
      expiresAt: map['expiresAt'] as String,
    );
  }
}

class PrivateChatLink {
  const PrivateChatLink({
    required this.chat,
    required this.appLink,
    required this.webLink,
  });

  final PrivateChatSession chat;
  final String appLink;
  final String webLink;
}

class PrivateChatMessage {
  const PrivateChatMessage({
    required this.id,
    required this.privateChatId,
    required this.senderUuid,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
    this.readAt,
  });

  final String id;
  final String privateChatId;
  final String senderUuid;
  final String body;
  final String createdAt;
  final String expiresAt;
  final String? readAt;

  factory PrivateChatMessage.fromMap(Map<String, dynamic> map) {
    return PrivateChatMessage(
      id: map['id'] as String,
      privateChatId: map['private_chat_id'] as String,
      senderUuid: map['sender_uuid'] as String,
      body: map['body'] as String,
      createdAt: map['created_at'] as String,
      expiresAt: map['expires_at'] as String,
      readAt: map['read_at'] as String?,
    );
  }
}
