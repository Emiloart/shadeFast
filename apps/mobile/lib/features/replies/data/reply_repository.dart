import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/reply.dart';

class ReplyRepositoryException implements Exception {
  const ReplyRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReplyRepository {
  const ReplyRepository(this._client);

  final SupabaseClient _client;

  static const _selectColumns =
      'id, post_id, parent_reply_id, user_uuid, body, created_at, expires_at';

  Future<List<ShadeReply>> fetchRepliesForPost({
    required String postId,
    int limit = 200,
  }) async {
    final rows = await _client
        .from('replies')
        .select(_selectColumns)
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .map(ShadeReply.fromMap)
        .toList(growable: false);
  }

  Future<ShadeReply> createReply({
    required String postId,
    required String body,
    String? parentReplyId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const ReplyRepositoryException('Anonymous session is not ready.');
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw const ReplyRepositoryException('Reply cannot be empty.');
    }

    if (trimmedBody.length > 1500) {
      throw const ReplyRepositoryException(
          'Reply must be 1500 chars or fewer.');
    }

    final row = await _client
        .from('replies')
        .insert(
          <String, dynamic>{
            'post_id': postId,
            'parent_reply_id': parentReplyId,
            'user_uuid': userId,
            'body': trimmedBody,
          },
        )
        .select(_selectColumns)
        .single();

    return ShadeReply.fromMap(Map<String, dynamic>.from(row as Map));
  }
}

final replyRepositoryProvider = Provider<ReplyRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return ReplyRepository(client);
});
