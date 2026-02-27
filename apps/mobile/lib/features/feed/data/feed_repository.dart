import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../posts/domain/post.dart';
import '../domain/feed_models.dart';

class FeedRepository {
  const FeedRepository(this._client);

  final SupabaseClient _client;

  static const _selectColumns =
      'id, community_id, user_uuid, content, image_url, video_url, '
      'like_count, view_count, created_at, expires_at';

  Future<FeedBatch> fetchGlobalFeed({
    int limit = 20,
    String? beforeCreatedAt,
  }) {
    return _fetchPosts(
      limit: limit,
      beforeCreatedAt: beforeCreatedAt,
      communityId: null,
    );
  }

  Future<FeedBatch> fetchCommunityFeed({
    required String communityId,
    int limit = 20,
    String? beforeCreatedAt,
  }) {
    return _fetchPosts(
      limit: limit,
      beforeCreatedAt: beforeCreatedAt,
      communityId: communityId,
    );
  }

  Future<FeedBatch> _fetchPosts({
    required int limit,
    required String? beforeCreatedAt,
    required String? communityId,
  }) async {
    var query = _client.from('posts').select(_selectColumns);

    if (communityId == null) {
      query = query.isFilter('community_id', null);
    } else {
      query = query.eq('community_id', communityId);
    }

    if (beforeCreatedAt != null && beforeCreatedAt.isNotEmpty) {
      query = query.lt('created_at', beforeCreatedAt);
    }

    final result =
        await query.order('created_at', ascending: false).limit(limit + 1);
    final rows = (result as List<dynamic>)
        .map(
          (dynamic item) => Map<String, dynamic>.from(item as Map),
        )
        .toList(growable: false);

    final posts = rows.map(ShadePost.fromMap).toList(growable: false);
    final hasMore = posts.length > limit;
    final visiblePosts = hasMore ? posts.sublist(0, limit) : posts;

    return FeedBatch(
      items: visiblePosts,
      hasMore: hasMore,
      nextCursor: visiblePosts.isEmpty ? null : visiblePosts.last.createdAt,
    );
  }
}

final feedRepositoryProvider = Provider<FeedRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return FeedRepository(client);
});
