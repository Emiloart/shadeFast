import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/experiment_edge_functions.dart';
import '../domain/feature_flag.dart';

final featureFlagSnapshotProvider =
    FutureProvider.autoDispose<FeatureFlagSnapshot>((Ref ref) async {
  final api = ref.watch(experimentEdgeFunctionsProvider);
  if (api == null) {
    throw const ExperimentApiException('Supabase is not configured.');
  }

  return api.listFeatureFlags(includeDisabled: true);
});
