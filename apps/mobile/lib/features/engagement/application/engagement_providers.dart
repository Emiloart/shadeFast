import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/engagement_edge_functions.dart';
import '../domain/engagement_models.dart';

final trendingPollsProvider = FutureProvider.autoDispose
    .family<List<TrendingPoll>, String?>((Ref ref, String? communityId) async {
  final api = ref.watch(engagementEdgeFunctionsProvider);
  if (api == null) {
    throw const EngagementApiException('Supabase is not configured.');
  }

  return api.listTrendingPolls(communityId: communityId);
});

final trendingChallengesProvider =
    FutureProvider.autoDispose<List<TrendingChallenge>>((Ref ref) async {
  final api = ref.watch(engagementEdgeFunctionsProvider);
  if (api == null) {
    throw const EngagementApiException('Supabase is not configured.');
  }

  return api.listTrendingChallenges();
});
