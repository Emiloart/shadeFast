class SubscriptionProduct {
  const SubscriptionProduct({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  factory SubscriptionProduct.fromMap(Map<String, dynamic> map) {
    return SubscriptionProduct(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class UserEntitlement {
  const UserEntitlement({
    required this.id,
    required this.productId,
    required this.status,
    required this.createdAt,
    required this.isActive,
    this.source,
    this.startedAt,
    this.expiresAt,
    this.revokedAt,
    this.metadata,
  });

  final String id;
  final String productId;
  final String status;
  final String? source;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isActive;

  factory UserEntitlement.fromMap(Map<String, dynamic> map) {
    return UserEntitlement(
      id: map['id'] as String,
      productId: map['productId'] as String,
      status: map['status'] as String? ?? 'unknown',
      source: map['source'] as String?,
      startedAt: _parseDate(map['startedAt']),
      expiresAt: _parseDate(map['expiresAt']),
      revokedAt: _parseDate(map['revokedAt']),
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
      createdAt:
          _parseDate(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      isActive: map['isActive'] as bool? ?? false,
    );
  }
}

class PremiumSnapshot {
  const PremiumSnapshot({
    required this.products,
    required this.entitlements,
  });

  final List<SubscriptionProduct> products;
  final List<UserEntitlement> entitlements;

  bool get hasActivePremium =>
      entitlements.any((e) => e.isActive && _isPremiumProduct(e.productId));

  UserEntitlement? get activePremiumEntitlement {
    for (final entitlement in entitlements) {
      if (entitlement.isActive && _isPremiumProduct(entitlement.productId)) {
        return entitlement;
      }
    }

    return null;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}

bool _isPremiumProduct(String productId) {
  return productId == 'premium_monthly' || productId == 'premium_yearly';
}
