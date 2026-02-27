import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/feature_flag.dart';

class ExperimentApiException implements Exception {
  const ExperimentApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExperimentEdgeFunctions {
  const ExperimentEdgeFunctions(this._client);

  final SupabaseClient _client;

  Future<FeatureFlagSnapshot> listFeatureFlags({
    bool includeDisabled = true,
  }) async {
    final response = await _client.functions.invoke(
      'list-feature-flags',
      body: <String, dynamic>{
        'includeDisabled': includeDisabled,
      },
    );

    if (response.status >= 400) {
      throw ExperimentApiException(
        _extractErrorMessage(response.data, 'Failed to load feature flags.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const ExperimentApiException(
          'Invalid list-feature-flags response.');
    }

    final flags = data['flags'];
    if (flags is! List<dynamic>) {
      throw const ExperimentApiException('Invalid feature flags payload.');
    }

    return FeatureFlagSnapshot(
      flags: flags
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .map(FeatureFlag.fromMap)
          .toList(growable: false),
    );
  }

  Future<void> trackExperimentEvent({
    required String eventName,
    Map<String, dynamic>? properties,
    String platform = 'unknown',
  }) async {
    final response = await _client.functions.invoke(
      'track-experiment-event',
      body: <String, dynamic>{
        'eventName': eventName,
        'properties': properties,
        'platform': platform,
      },
    );

    if (response.status >= 400) {
      throw ExperimentApiException(
        _extractErrorMessage(
            response.data, 'Failed to track experiment event.'),
      );
    }
  }
}

final experimentEdgeFunctionsProvider =
    Provider<ExperimentEdgeFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return ExperimentEdgeFunctions(client);
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
