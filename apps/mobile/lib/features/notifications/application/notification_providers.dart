import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_edge_functions.dart';
import '../domain/notification_event.dart';

final notificationFeedProvider =
    FutureProvider.autoDispose<NotificationFeedPage>((Ref ref) async {
  final api = ref.watch(notificationEdgeFunctionsProvider);
  if (api == null) {
    throw const NotificationApiException('Supabase is not configured.');
  }

  return api.listNotificationEvents();
});
