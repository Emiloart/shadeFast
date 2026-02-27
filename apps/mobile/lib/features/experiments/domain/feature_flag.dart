class FeatureFlag {
  const FeatureFlag({
    required this.id,
    required this.enabled,
    required this.rolloutPercentage,
    required this.config,
  });

  final String id;
  final bool enabled;
  final int rolloutPercentage;
  final Map<String, dynamic> config;

  factory FeatureFlag.fromMap(Map<String, dynamic> map) {
    return FeatureFlag(
      id: map['id'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? false,
      rolloutPercentage: map['rolloutPercentage'] as int? ?? 0,
      config: map['config'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['config'] as Map)
          : const <String, dynamic>{},
    );
  }
}

class FeatureFlagSnapshot {
  const FeatureFlagSnapshot({
    required this.flags,
  });

  final List<FeatureFlag> flags;

  bool isEnabled(String flagId, {bool fallback = false}) {
    for (final flag in flags) {
      if (flag.id == flagId) {
        return flag.enabled;
      }
    }

    return fallback;
  }
}
