class ShadeReply {
  const ShadeReply({
    required this.id,
    required this.postId,
    required this.userUuid,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
    this.parentReplyId,
  });

  final String id;
  final String postId;
  final String? parentReplyId;
  final String userUuid;
  final String body;
  final String createdAt;
  final String expiresAt;

  factory ShadeReply.fromMap(Map<String, dynamic> map) {
    return ShadeReply(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      parentReplyId: map['parent_reply_id'] as String?,
      userUuid: map['user_uuid'] as String,
      body: map['body'] as String,
      createdAt: map['created_at'] as String,
      expiresAt: map['expires_at'] as String,
    );
  }
}
