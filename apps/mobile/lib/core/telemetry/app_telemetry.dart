import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';

class AppTelemetry {
  const AppTelemetry(this._client);

  final SupabaseClient _client;

  Future<void> trackEvent({
    required String eventName,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    final trimmedName = eventName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      return;
    }

    try {
      await _client.functions.invoke(
        'track-experiment-event',
        body: <String, dynamic>{
          'eventName': trimmedName,
          'platform': 'mobile',
          'properties': sanitizeTelemetryProperties(properties),
        },
      );
    } catch (_) {
      // Never block product UX on telemetry failures.
    }
  }

  void trackEventInBackground({
    required String eventName,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    unawaited(
      trackEvent(
        eventName: eventName,
        properties: properties,
      ),
    );
  }
}

final appTelemetryProvider = Provider<AppTelemetry?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return AppTelemetry(client);
});

@visibleForTesting
Map<String, dynamic> sanitizeTelemetryProperties(
  Map<String, Object?> properties,
) {
  const maxProperties = 20;
  final sanitized = <String, dynamic>{};

  for (final entry in properties.entries) {
    if (sanitized.length >= maxProperties) {
      break;
    }

    final key = entry.key.trim();
    if (key.isEmpty || key.length > 40) {
      continue;
    }
    if (!_isSafePropertyKey(key)) {
      continue;
    }

    final value = _sanitizeValue(entry.value);
    if (value == null) {
      continue;
    }

    sanitized[key] = value;
  }

  return sanitized;
}

bool _isSafePropertyKey(String key) {
  final pattern = RegExp(r'^[a-zA-Z0-9_]+$');
  return pattern.hasMatch(key);
}

dynamic _sanitizeValue(Object? raw) {
  if (raw == null) {
    return null;
  }

  if (raw is bool) {
    return raw;
  }

  if (raw is num) {
    return raw;
  }

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.length <= 160 ? trimmed : trimmed.substring(0, 160);
  }

  if (raw is Enum) {
    return raw.name;
  }

  if (raw is List<Object?>) {
    final output = <String>[];
    for (final value in raw) {
      final sanitized = _sanitizeValue(value);
      if (sanitized is String && sanitized.isNotEmpty) {
        output.add(sanitized);
      }
      if (output.length >= 10) {
        break;
      }
    }
    return output;
  }

  return null;
}
