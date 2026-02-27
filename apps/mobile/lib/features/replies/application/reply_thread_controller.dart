import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reply_repository.dart';
import '../domain/reply.dart';

class ReplyThreadException implements Exception {
  const ReplyThreadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final replyThreadControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ReplyThreadController, List<ShadeReply>, String>(
  ReplyThreadController.new,
);

class ReplyThreadController
    extends AutoDisposeFamilyAsyncNotifier<List<ShadeReply>, String> {
  ReplyRepository? _repository;
  String? _postId;

  @override
  Future<List<ShadeReply>> build(String postId) async {
    final repository = ref.watch(replyRepositoryProvider);
    if (repository == null) {
      throw const ReplyThreadException('Supabase is not configured.');
    }

    _repository = repository;
    _postId = postId;
    return repository.fetchRepliesForPost(postId: postId);
  }

  Future<void> refresh() async {
    final repository = _repository;
    final postId = _postId;
    if (repository == null || postId == null) {
      return;
    }

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current);
    }

    final replies = await repository.fetchRepliesForPost(postId: postId);
    state = AsyncData(replies);
  }

  Future<void> createReply({
    required String body,
    String? parentReplyId,
  }) async {
    final repository = _repository;
    final postId = _postId;
    if (repository == null || postId == null) {
      throw const ReplyThreadException('Reply thread is not initialized.');
    }

    final reply = await repository.createReply(
      postId: postId,
      body: body,
      parentReplyId: parentReplyId,
    );

    final current = state.valueOrNull ?? <ShadeReply>[];
    final merged = <ShadeReply>[...current, reply]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = AsyncData(merged);
  }
}
