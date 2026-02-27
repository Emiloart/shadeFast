import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/moderation_edge_functions.dart';

class BlockedUsersException implements Exception {
  const BlockedUsersException(this.message);

  final String message;

  @override
  String toString() => message;
}

final blockedUsersControllerProvider =
    AsyncNotifierProvider<BlockedUsersController, Set<String>>(
        BlockedUsersController.new);

class BlockedUsersController extends AsyncNotifier<Set<String>> {
  ModerationEdgeFunctions? _api;

  @override
  Future<Set<String>> build() async {
    final api = ref.watch(moderationEdgeFunctionsProvider);
    if (api == null) {
      throw const BlockedUsersException('Supabase is not configured.');
    }

    _api = api;
    return api.fetchBlockedUserIds();
  }

  Future<void> blockUser(String blockedUserId) async {
    final api = _api ?? ref.read(moderationEdgeFunctionsProvider);
    if (api == null) {
      throw const BlockedUsersException('Supabase is not configured.');
    }

    await api.blockUser(blockedUserId: blockedUserId, unblock: false);

    final current = state.valueOrNull ?? <String>{};
    state = AsyncData(<String>{...current, blockedUserId});
  }

  Future<void> unblockUser(String blockedUserId) async {
    final api = _api ?? ref.read(moderationEdgeFunctionsProvider);
    if (api == null) {
      throw const BlockedUsersException('Supabase is not configured.');
    }

    await api.blockUser(blockedUserId: blockedUserId, unblock: true);

    final current = state.valueOrNull ?? <String>{};
    final next = <String>{...current}..remove(blockedUserId);
    state = AsyncData(next);
  }
}
