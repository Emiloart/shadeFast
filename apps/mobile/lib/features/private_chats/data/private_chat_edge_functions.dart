import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/private_chat.dart';

class PrivateChatApiException implements Exception {
  const PrivateChatApiException(
    this.message, {
    this.code,
  });

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class PrivateChatEdgeFunctions {
  const PrivateChatEdgeFunctions(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<PrivateChatLink> createPrivateChatLink({
    required bool readOnce,
    required int ttlMinutes,
  }) async {
    final response = await _client.functions.invoke(
      'create-private-chat-link',
      body: <String, dynamic>{
        'readOnce': readOnce,
        'ttlMinutes': ttlMinutes,
      },
    );

    if (response.status >= 400) {
      final details = _extractApiError(
        response.data,
        'Failed to create private chat link.',
      );
      throw PrivateChatApiException(
        details.message,
        code: details.code,
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const PrivateChatApiException(
          'Invalid create-private-chat-link response.');
    }

    final chatData = data['chat'];
    final linksData = data['links'];
    if (chatData is! Map<String, dynamic> ||
        linksData is! Map<String, dynamic>) {
      throw const PrivateChatApiException('Invalid private chat payload.');
    }

    final appLink = linksData['app'];
    final webLink = linksData['web'];
    if (appLink is! String || webLink is! String) {
      throw const PrivateChatApiException(
          'Invalid private chat links payload.');
    }

    return PrivateChatLink(
      chat: PrivateChatSession.fromMap(Map<String, dynamic>.from(chatData)),
      appLink: appLink,
      webLink: webLink,
    );
  }

  Future<PrivateChatSession> joinPrivateChatByToken(String token) async {
    final response = await _client.functions.invoke(
      'join-private-chat',
      body: <String, dynamic>{
        'token': token,
      },
    );

    if (response.status >= 400) {
      final details = _extractApiError(
        response.data,
        'Failed to join private chat.',
      );
      throw PrivateChatApiException(
        details.message,
        code: details.code,
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic> ||
        data['chat'] is! Map<String, dynamic>) {
      throw const PrivateChatApiException(
          'Invalid join-private-chat response.');
    }

    return PrivateChatSession.fromMap(
      Map<String, dynamic>.from(data['chat'] as Map),
    );
  }

  Stream<List<PrivateChatMessage>> watchMessages(String privateChatId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: <String>['id'])
        .eq('private_chat_id', privateChatId)
        .order('created_at', ascending: true)
        .map(
          (List<Map<String, dynamic>> rows) =>
              rows.map(PrivateChatMessage.fromMap).toList(growable: false),
        );
  }

  Future<void> sendMessage({
    required String privateChatId,
    required String body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const PrivateChatApiException('Anonymous session is not ready.');
    }

    final message = body.trim();
    if (message.isEmpty) {
      throw const PrivateChatApiException('Message cannot be empty.');
    }
    if (message.length > 2000) {
      throw const PrivateChatApiException(
          'Message must be 2000 chars or fewer.');
    }

    await _client.from('chat_messages').insert(
      <String, dynamic>{
        'private_chat_id': privateChatId,
        'sender_uuid': userId,
        'body': message,
      },
    );
  }

  Future<List<PrivateChatMessage>> readMessagesOnce(
      String privateChatId) async {
    final response = await _client.functions.invoke(
      'read-private-message-once',
      body: <String, dynamic>{
        'privateChatId': privateChatId,
      },
    );

    if (response.status >= 400) {
      final details = _extractApiError(
        response.data,
        'Failed to read once messages.',
      );
      throw PrivateChatApiException(
        details.message,
        code: details.code,
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const PrivateChatApiException(
          'Invalid read-private-message-once response.');
    }

    final messages = data['messages'];
    if (messages is! List<dynamic>) {
      throw const PrivateChatApiException(
          'Invalid read-private-message-once payload.');
    }

    return messages
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .map(PrivateChatMessage.fromMap)
        .toList(growable: false);
  }
}

final privateChatEdgeFunctionsProvider =
    Provider<PrivateChatEdgeFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return PrivateChatEdgeFunctions(client);
});

final joinPrivateChatProvider =
    FutureProvider.autoDispose.family<PrivateChatSession, String>((
  Ref ref,
  String token,
) async {
  final api = ref.watch(privateChatEdgeFunctionsProvider);
  if (api == null) {
    throw const PrivateChatApiException('Supabase is not configured.');
  }

  return api.joinPrivateChatByToken(token.trim().toUpperCase());
});

final privateChatMessagesProvider =
    StreamProvider.autoDispose.family<List<PrivateChatMessage>, String>((
  Ref ref,
  String privateChatId,
) {
  final api = ref.watch(privateChatEdgeFunctionsProvider);
  if (api == null) {
    throw const PrivateChatApiException('Supabase is not configured.');
  }

  return api.watchMessages(privateChatId);
});

_ApiErrorDetails _extractApiError(dynamic data, String fallback) {
  if (data is Map<String, dynamic>) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final code = error['code'];
      final message = error['message'];
      if (message is String && message.isNotEmpty && code is String) {
        return _ApiErrorDetails(code: code, message: message);
      }
      if (message is String && message.isNotEmpty) {
        return _ApiErrorDetails(code: 'unknown_error', message: message);
      }
    }
  }

  return _ApiErrorDetails(code: 'unknown_error', message: fallback);
}

class _ApiErrorDetails {
  const _ApiErrorDetails({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}
