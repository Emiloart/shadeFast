import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/engagement_providers.dart';
import '../data/engagement_edge_functions.dart';
import '../domain/engagement_models.dart';
import 'create_challenge_dialog.dart';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  bool _creating = false;
  final Set<String> _submittingChallengeIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final challengesAsync = ref.watch(trendingChallengesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trending Challenges')),
      body: challengesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => _ChallengesErrorState(
          message: 'Failed to load challenges: $error',
          onRetry: () => ref.invalidate(trendingChallengesProvider),
        ),
        data: (List<TrendingChallenge> challenges) {
          if (challenges.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  SizedBox(height: 180),
                  Center(
                    child: Text(
                      'No active challenges yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: challenges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, int index) {
                final challenge = challenges[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          challenge.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (challenge.description != null &&
                            challenge.description!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              challenge.description!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MetricChip(
                              label: 'Entries ${challenge.entryCount}',
                            ),
                            _MetricChip(
                              label: '24h ${challenge.recentEntryCount}',
                            ),
                            _MetricChip(
                              label: 'Users ${challenge.participantCount}',
                            ),
                            _MetricChip(
                              label: 'Score ${challenge.trendScore}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed:
                                _submittingChallengeIds.contains(challenge.id)
                                    ? null
                                    : () => _submitChallengeEntry(challenge),
                            icon: _submittingChallengeIds.contains(challenge.id)
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_task_outlined, size: 18),
                            label: const Text('Submit Entry'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ends ${_formatTimestamp(challenge.expiresAt)}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createChallenge,
        icon: _creating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.flag_outlined),
        label: Text(_creating ? 'Creating...' : 'New Challenge'),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(trendingChallengesProvider);
    await ref.read(trendingChallengesProvider.future);
  }

  Future<void> _createChallenge() async {
    final api = ref.read(engagementEdgeFunctionsProvider);
    if (api == null) {
      _showSnackBar('Supabase is not configured.');
      return;
    }

    final result = await showDialog<CreateChallengeDialogResult>(
      context: context,
      builder: (_) => const CreateChallengeDialog(),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      await api.createChallenge(
        CreateChallengeInput(
          title: result.title,
          description: result.description,
          durationDays: result.durationDays,
        ),
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(trendingChallengesProvider);
      _showSnackBar('Challenge created.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Create challenge failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitChallengeEntry(TrendingChallenge challenge) async {
    final api = ref.read(engagementEdgeFunctionsProvider);
    if (api == null) {
      _showSnackBar('Supabase is not configured.');
      return;
    }

    if (_submittingChallengeIds.contains(challenge.id)) {
      return;
    }

    setState(() {
      _submittingChallengeIds.add(challenge.id);
    });

    try {
      final posts = await api.listMyActivePosts();
      if (!mounted) {
        return;
      }

      if (posts.isEmpty) {
        _showSnackBar('Create a post first, then submit it to this challenge.');
        return;
      }

      final selectedPostId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF0B0B0B),
        isScrollControlled: true,
        builder: (_) => _ChallengePostPicker(posts: posts),
      );

      if (!mounted || selectedPostId == null) {
        return;
      }

      await api.submitChallengeEntry(
        challengeId: challenge.id,
        postId: selectedPostId,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(trendingChallengesProvider);
      _showSnackBar('Challenge entry submitted.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Submit entry failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _submittingChallengeIds.remove(challenge.id);
        });
      }
    }
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
        color: const Color(0xFF161616),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _ChallengesErrorState extends StatelessWidget {
  const _ChallengesErrorState({
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
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengePostPicker extends StatelessWidget {
  const _ChallengePostPicker({
    required this.posts,
  });

  final List<ChallengeEntryPost> posts;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pick a post to submit',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, int index) {
                  final post = posts[index];
                  final preview = (post.content ?? '').trim();
                  final previewText = preview.isEmpty
                      ? 'Media-only post'
                      : preview.length > 84
                          ? '${preview.substring(0, 84)}...'
                          : preview;

                  return ListTile(
                    tileColor: const Color(0xFF161616),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    title: Text(
                      previewText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _formatTimestamp(post.createdAt),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.of(context).pop(post.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final date = '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
