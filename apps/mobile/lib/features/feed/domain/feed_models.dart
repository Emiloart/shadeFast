import '../../posts/domain/post.dart';

class FeedBatch {
  const FeedBatch({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<ShadePost> items;
  final bool hasMore;
  final String? nextCursor;
}

class FeedPageState {
  const FeedPageState({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.isRefreshing,
    required this.nextCursor,
  });

  final List<ShadePost> items;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? nextCursor;

  factory FeedPageState.fromBatch(FeedBatch batch) {
    return FeedPageState(
      items: batch.items,
      hasMore: batch.hasMore,
      isLoadingMore: false,
      isRefreshing: false,
      nextCursor: batch.nextCursor,
    );
  }

  FeedPageState copyWith({
    List<ShadePost>? items,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? nextCursor,
  }) {
    return FeedPageState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }
}
