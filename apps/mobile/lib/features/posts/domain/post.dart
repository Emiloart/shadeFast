class ShadePost {
  const ShadePost({
    required this.id,
    required this.userUuid,
    required this.likeCount,
    required this.viewCount,
    required this.createdAt,
    required this.expiresAt,
    this.communityId,
    this.content,
    this.imageUrl,
    this.videoUrl,
  });

  final String id;
  final String? communityId;
  final String userUuid;
  final String? content;
  final String? imageUrl;
  final String? videoUrl;
  final int likeCount;
  final int viewCount;
  final String createdAt;
  final String expiresAt;

  factory ShadePost.fromMap(Map<String, dynamic> map) {
    return ShadePost(
      id: map['id'] as String,
      communityId: map['community_id'] as String?,
      userUuid: map['user_uuid'] as String,
      content: map['content'] as String?,
      imageUrl: map['image_url'] as String?,
      videoUrl: map['video_url'] as String?,
      likeCount: map['like_count'] as int? ?? 0,
      viewCount: map['view_count'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      expiresAt: map['expires_at'] as String,
    );
  }
}

class CreatePostInput {
  const CreatePostInput({
    this.communityId,
    this.content,
    this.imageUrl,
    this.videoUrl,
    this.ttlHours = 24,
  });

  final String? communityId;
  final String? content;
  final String? imageUrl;
  final String? videoUrl;
  final int ttlHours;
}
