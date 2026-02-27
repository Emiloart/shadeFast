import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/moderation_models.dart';

class ModerationApiException implements Exception {
  const ModerationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ModerationEdgeFunctions {
  const ModerationEdgeFunctions(this._client);

  final SupabaseClient _client;

  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    final response = await _client.functions.invoke(
      'report-content',
      body: <String, dynamic>{
        'postId': postId,
        'reason': reason,
        'details': details,
      },
    );

    if (response.status >= 400) {
      throw ModerationApiException(
        _extractErrorMessage(response.data, 'Failed to submit report.'),
      );
    }
  }

  Future<BlockUserResult> blockUser({
    required String blockedUserId,
    required bool unblock,
  }) async {
    final response = await _client.functions.invoke(
      'block-user',
      body: <String, dynamic>{
        'blockedUserId': blockedUserId,
        'action': unblock ? 'remove' : 'add',
      },
    );

    if (response.status >= 400) {
      throw ModerationApiException(
        _extractErrorMessage(response.data, 'Failed to update block list.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const ModerationApiException('Invalid block-user response.');
    }

    final isBlocked = data['blocked'];
    if (isBlocked is! bool) {
      throw const ModerationApiException('Invalid block status payload.');
    }

    return BlockUserResult(
      blockedUserId: blockedUserId,
      isBlocked: isBlocked,
    );
  }

  Future<Set<String>> fetchBlockedUserIds() async {
    final rows = await _client
        .from('blocks')
        .select('blocked_uuid')
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .map((Map<String, dynamic> row) => row['blocked_uuid'] as String?)
        .whereType<String>()
        .toSet();
  }
}

final moderationEdgeFunctionsProvider =
    Provider<ModerationEdgeFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return ModerationEdgeFunctions(client);
});

String _extractErrorMessage(dynamic data, String fallback) {
  if (data is Map<String, dynamic>) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
  }

  return fallback;
}
