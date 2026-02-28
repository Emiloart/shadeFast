import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/performance/app_performance_tracker.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../posts/domain/post.dart';
import '../data/feed_repository.dart';
import '../domain/feed_models.dart';

const _pageSize = 20;

class FeedException implements Exception {
  const FeedException(this.message);

  final String message;

  @override
  String toString() => message;
}

final globalFeedControllerProvider =
    AsyncNotifierProvider.autoDispose<GlobalFeedController, FeedPageState>(
        GlobalFeedController.new);

class GlobalFeedController extends AutoDisposeAsyncNotifier<FeedPageState> {
  FeedRepository? _repository;
  RealtimeChannel? _channel;

  @override
  Future<FeedPageState> build() async {
    final repository = ref.watch(feedRepositoryProvider);
    final performanceTracker = ref.read(appPerformanceTrackerProvider);
    if (repository == null) {
      throw const FeedException('Supabase is not configured.');
    }

    _repository = repository;
    _subscribeToRealtime();

    final stopwatch = Stopwatch()..start();
    try {
      final firstBatch = await repository.fetchGlobalFeed(limit: _pageSize);
      performanceTracker.trackFeedFetchCompleted(
        feedType: 'global',
        phase: 'initial_load',
        elapsedMs: stopwatch.elapsedMilliseconds,
        itemCount: firstBatch.items.length,
        hasMore: firstBatch.hasMore,
      );
      return FeedPageState.fromBatch(firstBatch);
    } catch (error) {
      performanceTracker.trackFeedFetchFailed(
        feedType: 'global',
        phase: 'initial_load',
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      rethrow;
    }
  }

  Future<void> refreshFromTop() async {
    final repository = _repository;
    final performanceTracker = ref.read(appPerformanceTrackerProvider);
    if (repository == null) {
      return;
    }

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(isRefreshing: true));
    }

    final stopwatch = Stopwatch()..start();
    try {
      final firstBatch = await repository.fetchGlobalFeed(limit: _pageSize);
      performanceTracker.trackFeedFetchCompleted(
        feedType: 'global',
        phase: 'refresh',
        elapsedMs: stopwatch.elapsedMilliseconds,
        itemCount: firstBatch.items.length,
        hasMore: firstBatch.hasMore,
      );
      state = AsyncData(FeedPageState.fromBatch(firstBatch));
    } catch (error, stackTrace) {
      performanceTracker.trackFeedFetchFailed(
        feedType: 'global',
        phase: 'refresh',
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      if (current != null) {
        state = AsyncData(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> loadMore() async {
    final repository = _repository;
    final performanceTracker = ref.read(appPerformanceTrackerProvider);
    final current = state.valueOrNull;

    if (repository == null || current == null) {
      return;
    }

    if (!current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final stopwatch = Stopwatch()..start();
    try {
      final batch = await repository.fetchGlobalFeed(
        limit: _pageSize,
        beforeCreatedAt: current.nextCursor,
      );

      final mergedItems = _mergePostsById(current.items, batch.items);

      state = AsyncData(
        current.copyWith(
          items: mergedItems,
          hasMore: batch.hasMore,
          nextCursor: batch.nextCursor,
          isLoadingMore: false,
        ),
      );
      performanceTracker.trackFeedFetchCompleted(
        feedType: 'global',
        phase: 'load_more',
        elapsedMs: stopwatch.elapsedMilliseconds,
        itemCount: batch.items.length,
        hasMore: batch.hasMore,
      );
    } catch (error) {
      performanceTracker.trackFeedFetchFailed(
        feedType: 'global',
        phase: 'load_more',
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  void _subscribeToRealtime() {
    final client = ref.read(supabaseClientProvider);
    if (client == null || _channel != null) {
      return;
    }

    final channel = client.channel(
      'global-feed-${DateTime.now().millisecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (_) {
            refreshFromTop();
          },
        )
        .subscribe();

    _channel = channel;

    ref.onDispose(() {
      final activeChannel = _channel;
      if (activeChannel != null) {
        client.removeChannel(activeChannel);
      }
      _channel = null;
    });
  }
}

final communityFeedControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CommunityFeedController, FeedPageState, String>(
        CommunityFeedController.new);

class CommunityFeedController
    extends AutoDisposeFamilyAsyncNotifier<FeedPageState, String> {
  FeedRepository? _repository;
  String? _communityId;
  RealtimeChannel? _channel;

  @override
  Future<FeedPageState> build(String communityId) async {
    final repository = ref.watch(feedRepositoryProvider);
    final performanceTracker = ref.read(appPerformanceTrackerProvider);
    if (repository == null) {
      throw const FeedException('Supabase is not configured.');
    }

    _repository = repository;
    _communityId = communityId;
    _subscribeToRealtime(communityId);

    final stopwatch = Stopwatch()..start();
    try {
      final firstBatch = await repository.fetchCommunityFeed(
        communityId: communityId,
        limit: _pageSize,
      );
      performanceTracker.trackFeedFetchCompleted(
        feedType: 'community',
        phase: 'initial_load',
        elapsedMs: stopwatch.elapsedMilliseconds,
        itemCount: firstBatch.items.length,
        hasMore: firstBatch.hasMore,
      );

      return FeedPageState.fromBatch(firstBatch);
    } catch (error) {
      performanceTracker.trackFeedFetchFailed(
        feedType: 'community',
        phase: 'initial_load',
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      rethrow;
    }
  }

  Future<void> refreshFromTop() async {
    final repository = _repository;
    final performanceTracker = ref.read(appPerformanceTrackerProvider);
    final current = state.valueOrNull;
    final communityId = _communityId;

    if (repository == null || communityId == null) {
      return;
    }

    if (current != null) {
      state = AsyncData(current.copyWith(isRefreshing: true));
    }

    final stopwatch = Stopwatch()..start();
    try {
      final firstBatch = await repository.fetchCommunityFeed(
        communityId: communityId,
        limit: _pageSize,
      );
      performanceTracker.trackFeedFetchCompleted(
        feedType: 'community',
        phase: 'refresh',
        elapsedMs: stopwatch.elapsedMilliseconds,
        itemCount: firstBatch.items.length,
        hasMore: firstBatch.hasMore,
      );
      state = AsyncData(FeedPageState.fromBatch(firstBatch));
    } catch (error, stackTrace) {
      performanceTracker.trackFeedFetchFailed(
        feedType: 'community',
        phase: 'refresh',
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      if (current != null) {
        state = AsyncData(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> loadMore() async {
    final repository = _repository;
    final performanceTracker = ref.read(appPerformanceTrackerProvider);
    final current = state.valueOrNull;
    final communityId = _communityId;

    if (repository == null || current == null || communityId == null) {
      return;
    }

    if (!current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final stopwatch = Stopwatch()..start();
    try {
      final batch = await repository.fetchCommunityFeed(
        communityId: communityId,
        limit: _pageSize,
        beforeCreatedAt: current.nextCursor,
      );

      final mergedItems = _mergePostsById(current.items, batch.items);

      state = AsyncData(
        current.copyWith(
          items: mergedItems,
          hasMore: batch.hasMore,
          nextCursor: batch.nextCursor,
          isLoadingMore: false,
        ),
      );
      performanceTracker.trackFeedFetchCompleted(
        feedType: 'community',
        phase: 'load_more',
        elapsedMs: stopwatch.elapsedMilliseconds,
        itemCount: batch.items.length,
        hasMore: batch.hasMore,
      );
    } catch (error) {
      performanceTracker.trackFeedFetchFailed(
        feedType: 'community',
        phase: 'load_more',
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  void _subscribeToRealtime(String communityId) {
    final client = ref.read(supabaseClientProvider);
    if (client == null || _channel != null) {
      return;
    }

    final channel = client.channel(
      'community-feed-$communityId-${DateTime.now().millisecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (_) {
            refreshFromTop();
          },
        )
        .subscribe();

    _channel = channel;

    ref.onDispose(() {
      final activeChannel = _channel;
      if (activeChannel != null) {
        client.removeChannel(activeChannel);
      }
      _channel = null;
    });
  }
}

List<ShadePost> _mergePostsById(
  List<ShadePost> current,
  List<ShadePost> incoming,
) {
  final result = <ShadePost>[...current];
  final seenIds = <String>{...current.map((ShadePost post) => post.id)};

  for (final post in incoming) {
    if (seenIds.contains(post.id)) {
      continue;
    }
    result.add(post);
    seenIds.add(post.id);
  }

  return result;
}
