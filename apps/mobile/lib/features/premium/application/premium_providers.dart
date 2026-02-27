import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/premium_edge_functions.dart';
import '../domain/premium_models.dart';

final premiumSnapshotProvider =
    FutureProvider.autoDispose<PremiumSnapshot>((Ref ref) async {
  final api = ref.watch(premiumEdgeFunctionsProvider);
  if (api == null) {
    throw const PremiumApiException('Supabase is not configured.');
  }

  final products = await api.listSubscriptionProducts();
  final entitlements = await api.listUserEntitlements(includeExpired: false);

  return PremiumSnapshot(
    products: products,
    entitlements: entitlements,
  );
});
