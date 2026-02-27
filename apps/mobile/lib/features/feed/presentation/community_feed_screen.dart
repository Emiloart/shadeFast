import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../moderation/application/blocked_users_controller.dart';
import '../../moderation/data/moderation_edge_functions.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/report_post_dialog.dart';
import '../../posts/data/post_edge_functions.dart';
import '../../posts/domain/post.dart';
import '../../posts/presentation/create_post_dialog.dart';
import '../../replies/presentation/post_replies_sheet.dart';
import '../application/feed_controllers.dart';
import '../domain/feed_models.dart';
import 'post_content.dart';

class CommunityFeedScreen extends ConsumerWidget {
  const CommunityFeedScreen({
    required this.communityId,
    super.key,
  });

  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(communityFeedControllerProvider(communityId));
    final likedPosts = ref.watch(likedPostIdsProvider);
    final blockedUsers =
        ref.watch(blockedUsersControllerProvider).valueOrNull ?? <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/polls?communityId=$communityId'),
            tooltip: 'Community Polls',
            icon: const Icon(Icons.poll_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/challenges'),
            tooltip: 'Trending Challenges',
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/premium'),
            tooltip: 'Premium',
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/notifications'),
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => _FeedErrorState(
          message: 'Failed to load feed: $error',
          onRetry: () =>
              ref.invalidate(communityFeedControllerProvider(communityId)),
        ),
        data: (FeedPageState state) {
          final visiblePosts = state.items
              .where((ShadePost post) => !blockedUsers.contains(post.userUuid))
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: () => ref
                .read(communityFeedControllerProvider(communityId).notifier)
                .refreshFromTop(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 300) {
                  ref
                      .read(
                          communityFeedControllerProvider(communityId).notifier)
                      .loadMore();
                }
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: visiblePosts.length + 1,
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, int index) {
                  if (index == visiblePosts.length) {
                    return _FeedFooter(
                      state: state,
                      visibleCount: visiblePosts.length,
                    );
                  }

                  final post = visiblePosts[index];
                  final isAuthorBlocked = blockedUsers.contains(post.userUuid);

                  return _FeedPostCard(
                    post: post,
                    isLiked: likedPosts.contains(post.id),
                    isAuthorBlocked: isAuthorBlocked,
                    onToggleLike: () => _toggleLike(ref, communityId, post),
                    onOpenReplies: () => _showRepliesSheet(context, post.id),
                    onReport: () => _reportPost(context, ref, post),
                    onToggleAuthorBlock: () => _toggleAuthorBlock(
                      context,
                      ref,
                      communityId,
                      post,
                      isCurrentlyBlocked: isAuthorBlocked,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showCreateCommunityPostDialog(context, ref, communityId),
        label: const Text('Post'),
        icon: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}

Future<void> _toggleLike(
    WidgetRef ref, String communityId, ShadePost post) async {
  final api = ref.read(postEdgeFunctionsProvider);
  if (api == null) {
    return;
  }

  final likedPosts = ref.read(likedPostIdsProvider);
  final isLiked = likedPosts.contains(post.id);

  try {
    final reaction = await api.reactToPost(
      postId: post.id,
      removeReaction: isLiked,
    );

    final next = <String>{...likedPosts};
    if (reaction.liked) {
      next.add(post.id);
    } else {
      next.remove(post.id);
    }
    ref.read(likedPostIdsProvider.notifier).state = next;
    ref
        .read(communityFeedControllerProvider(communityId).notifier)
        .refreshFromTop();
  } catch (_) {
    // Ignore for now; UI state remains unchanged.
  }
}

Future<void> _reportPost(
    BuildContext context, WidgetRef ref, ShadePost post) async {
  final api = ref.read(moderationEdgeFunctionsProvider);
  if (api == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supabase is not configured.')),
    );
    return;
  }

  final input = await showDialog<ReportContentInput>(
    context: context,
    builder: (_) => const ReportPostDialog(),
  );

  if (input == null) {
    return;
  }

  try {
    await api.reportPost(
      postId: post.id,
      reason: input.reason,
      details: input.details,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted.')),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report failed: $error')),
    );
  }
}

Future<void> _toggleAuthorBlock(
  BuildContext context,
  WidgetRef ref,
  String communityId,
  ShadePost post, {
  required bool isCurrentlyBlocked,
}) async {
  final blockedController = ref.read(blockedUsersControllerProvider.notifier);

  try {
    if (isCurrentlyBlocked) {
      await blockedController.unblockUser(post.userUuid);
    } else {
      await blockedController.blockUser(post.userUuid);
    }

    ref
        .read(communityFeedControllerProvider(communityId).notifier)
        .refreshFromTop();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCurrentlyBlocked ? 'Author unblocked.' : 'Author blocked.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Block action failed: $error')),
    );
  }
}

Future<void> _showCreateCommunityPostDialog(
  BuildContext context,
  WidgetRef ref,
  String communityId,
) async {
  final api = ref.read(postEdgeFunctionsProvider);
  if (api == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supabase is not configured.')),
    );
    return;
  }

  final dialogResult = await showDialog<CreatePostDialogResult>(
    context: context,
    builder: (_) => const CreatePostDialog(),
  );

  if (dialogResult == null) {
    return;
  }

  try {
    String? imageUrl;
    final imagePath = dialogResult.imagePath?.trim();
    if (imagePath != null && imagePath.isNotEmpty) {
      imageUrl = await api.uploadPostImage(imagePath);
    }

    String? videoUrl;
    final videoPath = dialogResult.videoPath?.trim();
    if (videoPath != null && videoPath.isNotEmpty) {
      videoUrl = await api.uploadPostVideo(videoPath);
    }

    final post = await api.createPost(
      CreatePostInput(
        communityId: communityId,
        content: dialogResult.content,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        ttlHours: dialogResult.ttlHours,
      ),
    );

    ref
        .read(communityFeedControllerProvider(communityId).notifier)
        .refreshFromTop();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Posted. Expires at ${post.expiresAt}.')),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Post failed: $error')),
    );
  }
}

Future<void> _showRepliesSheet(BuildContext context, String postId) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0B0B0B),
    builder: (_) => PostRepliesSheet(postId: postId),
  );
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.post,
    required this.isLiked,
    required this.isAuthorBlocked,
    required this.onToggleLike,
    required this.onOpenReplies,
    required this.onReport,
    required this.onToggleAuthorBlock,
  });

  final ShadePost post;
  final bool isLiked;
  final bool isAuthorBlocked;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenReplies;
  final VoidCallback onReport;
  final VoidCallback onToggleAuthorBlock;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: FeedPostContent(
                    content: post.content,
                    imageUrl: post.imageUrl,
                    videoUrl: post.videoUrl,
                  ),
                ),
                PopupMenuButton<_PostAction>(
                  icon: const Icon(Icons.more_horiz, color: Colors.white70),
                  color: const Color(0xFF111111),
                  onSelected: (_PostAction action) {
                    switch (action) {
                      case _PostAction.report:
                        onReport();
                        break;
                      case _PostAction.blockAuthor:
                      case _PostAction.unblockAuthor:
                        onToggleAuthorBlock();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_PostAction>>[
                    const PopupMenuItem<_PostAction>(
                      value: _PostAction.report,
                      child: Text('Report post'),
                    ),
                    PopupMenuItem<_PostAction>(
                      value: isAuthorBlocked
                          ? _PostAction.unblockAuthor
                          : _PostAction.blockAuthor,
                      child: Text(
                        isAuthorBlocked ? 'Unblock author' : 'Block author',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                InkWell(
                  onTap: onToggleLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isLiked
                              ? const Color(0xFFFF2D55)
                              : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.likeCount}',
                          style: TextStyle(
                            color: isLiked
                                ? const Color(0xFFFF2D55)
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                InkWell(
                  onTap: onOpenReplies,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Reply',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.viewCount}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  _compactTime(post.createdAt),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({
    required this.state,
    required this.visibleCount,
  });

  final FeedPageState state;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!state.hasMore) {
      String message;
      if (visibleCount == 0 && state.items.isNotEmpty) {
        message = 'All posts hidden (blocked users).';
      } else if (visibleCount == 0) {
        message = 'No posts yet.';
      } else {
        message = 'You are all caught up.';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return const SizedBox(height: 24);
  }
}

class _FeedErrorState extends StatelessWidget {
  const _FeedErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _compactTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final now = DateTime.now().toUtc();
  final diff = now.difference(parsed.toUtc());

  if (diff.inMinutes < 1) {
    return 'now';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h';
  }

  return '${diff.inDays}d';
}

enum _PostAction {
  report,
  blockAuthor,
  unblockAuthor,
}
