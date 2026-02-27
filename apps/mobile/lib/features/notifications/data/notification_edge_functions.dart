import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/notification_event.dart';

class NotificationApiException implements Exception {
  const NotificationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationEdgeFunctions {
  const NotificationEdgeFunctions(this._client);

  final SupabaseClient _client;

  Future<NotificationFeedPage> listNotificationEvents({
    int limit = 30,
    String? beforeCreatedAt,
    String? eventType,
  }) async {
    final response = await _client.functions.invoke(
      'list-notification-events',
      body: <String, dynamic>{
        'limit': limit,
        'beforeCreatedAt': beforeCreatedAt,
        'eventType': eventType,
      },
    );

    if (response.status >= 400) {
      throw NotificationApiException(
        _extractErrorMessage(response.data, 'Failed to load notifications.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const NotificationApiException(
          'Invalid list-notification-events response.');
    }

    final events = data['events'];
    final undeliveredCount = data['undeliveredCount'];
    if (events is! List<dynamic> || undeliveredCount is! int) {
      throw const NotificationApiException('Invalid notifications payload.');
    }

    return NotificationFeedPage(
      events: events
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .map(NotificationEvent.fromMap)
          .toList(growable: false),
      undeliveredCount: undeliveredCount,
    );
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? locale,
    String? appVersion,
  }) async {
    final response = await _client.functions.invoke(
      'register-push-token',
      body: <String, dynamic>{
        'token': token,
        'platform': platform,
        'locale': locale,
        'appVersion': appVersion,
      },
    );

    if (response.status >= 400) {
      throw NotificationApiException(
        _extractErrorMessage(response.data, 'Failed to register push token.'),
      );
    }
  }

  Future<void> unregisterPushToken({String? token}) async {
    final response = await _client.functions.invoke(
      'unregister-push-token',
      body: <String, dynamic>{
        'token': token,
      },
    );

    if (response.status >= 400) {
      throw NotificationApiException(
        _extractErrorMessage(response.data, 'Failed to unregister push token.'),
      );
    }
  }
}

final notificationEdgeFunctionsProvider =
    Provider<NotificationEdgeFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return NotificationEdgeFunctions(client);
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
