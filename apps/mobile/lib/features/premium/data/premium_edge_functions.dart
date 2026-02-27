import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/premium_models.dart';

class PremiumApiException implements Exception {
  const PremiumApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PremiumEdgeFunctions {
  const PremiumEdgeFunctions(this._client);

  final SupabaseClient _client;

  Future<List<SubscriptionProduct>> listSubscriptionProducts() async {
    final response = await _client.functions.invoke(
      'list-subscription-products',
      body: <String, dynamic>{},
    );

    if (response.status >= 400) {
      throw PremiumApiException(
        _extractErrorMessage(response.data, 'Failed to load products.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const PremiumApiException('Invalid list-subscription-products response.');
    }

    final products = data['products'];
    if (products is! List<dynamic>) {
      throw const PremiumApiException('Invalid products payload.');
    }

    return products
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .map(SubscriptionProduct.fromMap)
        .toList(growable: false);
  }

  Future<List<UserEntitlement>> listUserEntitlements({
    bool includeExpired = false,
  }) async {
    final response = await _client.functions.invoke(
      'list-user-entitlements',
      body: <String, dynamic>{
        'includeExpired': includeExpired,
      },
    );

    if (response.status >= 400) {
      throw PremiumApiException(
        _extractErrorMessage(response.data, 'Failed to load entitlements.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const PremiumApiException('Invalid list-user-entitlements response.');
    }

    final entitlements = data['entitlements'];
    if (entitlements is! List<dynamic>) {
      throw const PremiumApiException('Invalid entitlements payload.');
    }

    return entitlements
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .map(UserEntitlement.fromMap)
        .toList(growable: false);
  }

  Future<UserEntitlement> activatePremiumTrial({int days = 3}) async {
    final response = await _client.functions.invoke(
      'activate-premium-trial',
      body: <String, dynamic>{
        'days': days,
      },
    );

    if (response.status >= 400) {
      throw PremiumApiException(
        _extractErrorMessage(response.data, 'Failed to activate premium trial.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const PremiumApiException('Invalid activate-premium-trial response.');
    }

    final entitlement = data['entitlement'];
    if (entitlement is! Map<String, dynamic>) {
      throw const PremiumApiException('Invalid trial entitlement payload.');
    }

    return UserEntitlement(
      id: entitlement['id'] as String,
      productId: entitlement['productId'] as String,
      status: entitlement['status'] as String? ?? 'active',
      source: entitlement['source'] as String?,
      startedAt: _parseDate(entitlement['startedAt']),
      expiresAt: _parseDate(entitlement['expiresAt']),
      revokedAt: null,
      metadata: const <String, dynamic>{'trial': true},
      createdAt: DateTime.now().toUtc(),
      isActive: true,
    );
  }
}

final premiumEdgeFunctionsProvider = Provider<PremiumEdgeFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return PremiumEdgeFunctions(client);
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

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
