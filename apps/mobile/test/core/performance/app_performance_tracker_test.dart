import 'package:flutter_test/flutter_test.dart';

import 'package:shadefast_mobile/core/performance/app_performance_tracker.dart';

void main() {
  test('buildStartupPerformanceProperties clamps negative durations', () {
    final properties = buildStartupPerformanceProperties(
      elapsedMs: -12,
      outcome: ' ready ',
    );

    expect(properties['elapsed_ms'], 0);
    expect(properties['outcome'], 'ready');
  });

  test('buildFeedPerformanceProperties marks failures and exception type', () {
    final properties = buildFeedPerformanceProperties(
      feedType: 'community',
      phase: 'load_more',
      elapsedMs: 250,
      itemCount: -3,
      hasMore: false,
      exceptionType: ' StateError ',
    );

    expect(properties['feed_type'], 'community');
    expect(properties['phase'], 'load_more');
    expect(properties['elapsed_ms'], 250);
    expect(properties['item_count'], 0);
    expect(properties['has_more'], isFalse);
    expect(properties['success'], isFalse);
    expect(properties['exception_type'], 'StateError');
  });

  test('buildFeedPaintProperties captures empty feed paints safely', () {
    final properties = buildFeedPaintProperties(
      feedType: 'global',
      visibleCount: -1,
      hasMore: true,
      elapsedSinceLaunchMs: 9999999,
    );

    expect(properties['feed_type'], 'global');
    expect(properties['visible_count'], 0);
    expect(properties['has_content'], isFalse);
    expect(properties['has_more'], isTrue);
    expect(properties['elapsed_since_launch_ms'], 600000);
  });
}
