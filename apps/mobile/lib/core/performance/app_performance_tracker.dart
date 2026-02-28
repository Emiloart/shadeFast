import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../telemetry/app_telemetry.dart';

final Stopwatch _appSessionStopwatch = Stopwatch()..start();

class AppPerformanceTracker {
  AppPerformanceTracker(this._telemetry);

  final AppTelemetry? _telemetry;

  bool _hasTrackedAppFirstFrame = false;
  bool _hasTrackedStartupReady = false;

  void trackAppFirstFrame() {
    if (_hasTrackedAppFirstFrame) {
      return;
    }

    _hasTrackedAppFirstFrame = true;
    _trackInBackground(
      eventName: 'app_first_frame',
      properties: buildStartupPerformanceProperties(
        elapsedMs: _appSessionStopwatch.elapsedMilliseconds,
        outcome: 'first_frame',
      ),
    );
  }

  void trackStartupResolved({
    required String outcome,
  }) {
    if (_hasTrackedStartupReady) {
      return;
    }

    _hasTrackedStartupReady = true;
    _trackInBackground(
      eventName: 'app_startup_ready',
      properties: buildStartupPerformanceProperties(
        elapsedMs: _appSessionStopwatch.elapsedMilliseconds,
        outcome: outcome,
      ),
    );
  }

  void trackFeedFetchCompleted({
    required String feedType,
    required String phase,
    required int elapsedMs,
    required int itemCount,
    required bool hasMore,
  }) {
    _trackInBackground(
      eventName: 'feed_fetch_completed',
      properties: buildFeedPerformanceProperties(
        feedType: feedType,
        phase: phase,
        elapsedMs: elapsedMs,
        itemCount: itemCount,
        hasMore: hasMore,
      ),
    );
  }

  void trackFeedFetchFailed({
    required String feedType,
    required String phase,
    required int elapsedMs,
    required Object error,
  }) {
    _trackInBackground(
      eventName: 'feed_fetch_failed',
      properties: buildFeedPerformanceProperties(
        feedType: feedType,
        phase: phase,
        elapsedMs: elapsedMs,
        itemCount: 0,
        hasMore: false,
        exceptionType: error.runtimeType.toString(),
      ),
    );
  }

  void trackFeedFirstContentPaint({
    required String feedType,
    required int visibleCount,
    required bool hasMore,
  }) {
    _trackInBackground(
      eventName: 'feed_first_content_paint',
      properties: buildFeedPaintProperties(
        feedType: feedType,
        visibleCount: visibleCount,
        hasMore: hasMore,
        elapsedSinceLaunchMs: _appSessionStopwatch.elapsedMilliseconds,
      ),
    );
  }

  void _trackInBackground({
    required String eventName,
    required Map<String, Object?> properties,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }

    unawaited(
      telemetry.trackEvent(
        eventName: eventName,
        properties: properties,
      ),
    );
  }
}

final appPerformanceTrackerProvider = Provider<AppPerformanceTracker>((ref) {
  final telemetry = ref.watch(appTelemetryProvider);
  return AppPerformanceTracker(telemetry);
});

@visibleForTesting
Map<String, Object?> buildStartupPerformanceProperties({
  required int elapsedMs,
  required String outcome,
}) {
  return <String, Object?>{
    'elapsed_ms': _clampElapsedMs(elapsedMs),
    'outcome': _normalizeDimension(outcome, fallback: 'unknown'),
  };
}

@visibleForTesting
Map<String, Object?> buildFeedPerformanceProperties({
  required String feedType,
  required String phase,
  required int elapsedMs,
  required int itemCount,
  required bool hasMore,
  String? exceptionType,
}) {
  final normalizedExceptionType = exceptionType == null
      ? null
      : _normalizeDimension(exceptionType, fallback: '');

  return <String, Object?>{
    'feed_type': _normalizeDimension(feedType, fallback: 'feed'),
    'phase': _normalizeDimension(phase, fallback: 'unknown'),
    'elapsed_ms': _clampElapsedMs(elapsedMs),
    'item_count': itemCount < 0 ? 0 : itemCount,
    'has_more': hasMore,
    'success':
        normalizedExceptionType == null || normalizedExceptionType.isEmpty,
    if (normalizedExceptionType != null && normalizedExceptionType.isNotEmpty)
      'exception_type': normalizedExceptionType,
  };
}

@visibleForTesting
Map<String, Object?> buildFeedPaintProperties({
  required String feedType,
  required int visibleCount,
  required bool hasMore,
  required int elapsedSinceLaunchMs,
}) {
  final sanitizedVisibleCount = visibleCount < 0 ? 0 : visibleCount;
  return <String, Object?>{
    'feed_type': _normalizeDimension(feedType, fallback: 'feed'),
    'visible_count': sanitizedVisibleCount,
    'has_content': sanitizedVisibleCount > 0,
    'has_more': hasMore,
    'elapsed_since_launch_ms': _clampElapsedMs(elapsedSinceLaunchMs),
  };
}

int _clampElapsedMs(int value) {
  if (value < 0) {
    return 0;
  }

  const maxElapsedMs = 10 * 60 * 1000;
  if (value > maxElapsedMs) {
    return maxElapsedMs;
  }

  return value;
}

String _normalizeDimension(
  String raw, {
  required String fallback,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }

  return trimmed.length <= 40 ? trimmed : trimmed.substring(0, 40);
}
