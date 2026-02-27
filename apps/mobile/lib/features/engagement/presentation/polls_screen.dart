import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/engagement_providers.dart';
import '../data/engagement_edge_functions.dart';
import '../domain/engagement_models.dart';
import 'create_poll_dialog.dart';

class PollsScreen extends ConsumerStatefulWidget {
  const PollsScreen({
    super.key,
    this.communityId,
  });

  final String? communityId;

  @override
  ConsumerState<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends ConsumerState<PollsScreen> {
  final Set<String> _votingPollIds = <String>{};
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final pollsAsync = ref.watch(trendingPollsProvider(widget.communityId));

    return Scaffold(
      appBar: AppBar(title: const Text('Trending Polls')),
      body: pollsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => _PollsErrorState(
          message: 'Failed to load polls: $error',
          onRetry: () =>
              ref.invalidate(trendingPollsProvider(widget.communityId)),
        ),
        data: (List<TrendingPoll> polls) {
          if (polls.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  SizedBox(height: 180),
                  Center(
                    child: Text(
                      'No active polls yet. Start one.',
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
              itemBuilder: (_, int index) => _PollCard(
                poll: polls[index],
                isVoting: _votingPollIds.contains(polls[index].id),
                onVote: (int optionIndex) =>
                    _votePoll(polls[index], optionIndex),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: polls.length,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createPoll,
        icon: _creating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.poll_outlined),
        label: Text(_creating ? 'Creating...' : 'New Poll'),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(trendingPollsProvider(widget.communityId));
    await ref.read(trendingPollsProvider(widget.communityId).future);
  }

  Future<void> _createPoll() async {
    final api = ref.read(engagementEdgeFunctionsProvider);
    if (api == null) {
      _showSnackBar('Supabase is not configured.');
      return;
    }

    final result = await showDialog<CreatePollDialogResult>(
      context: context,
      builder: (_) => const CreatePollDialog(),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      await api.createPoll(
        CreatePollInput(
          communityId: widget.communityId,
          question: result.question,
          options: result.options,
          content: result.content,
        ),
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(trendingPollsProvider(widget.communityId));
      _showSnackBar('Poll created.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Create poll failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  Future<void> _votePoll(TrendingPoll poll, int optionIndex) async {
    final api = ref.read(engagementEdgeFunctionsProvider);
    if (api == null) {
      _showSnackBar('Supabase is not configured.');
      return;
    }

    if (_votingPollIds.contains(poll.id)) {
      return;
    }

    setState(() {
      _votingPollIds.add(poll.id);
    });

    try {
      await api.votePoll(pollId: poll.id, optionIndex: optionIndex);
      if (!mounted) {
        return;
      }

      ref.invalidate(trendingPollsProvider(widget.communityId));
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Vote failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _votingPollIds.remove(poll.id);
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.poll,
    required this.onVote,
    required this.isVoting,
  });

  final TrendingPoll poll;
  final bool isVoting;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              poll.question,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (poll.postContent != null && poll.postContent!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  poll.postContent!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            const SizedBox(height: 10),
            for (var index = 0; index < poll.options.length; index++)
              _PollOptionTile(
                text: poll.options[index],
                count: index < poll.counts.length ? poll.counts[index] : 0,
                totalVotes: poll.totalVotes,
                selected: poll.selectedOptionIndex == index,
                disabled: isVoting,
                onTap: () => onVote(index),
              ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Text(
                  '${poll.totalVotes} votes',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Text(
                  'Score ${poll.trendScore}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.text,
    required this.count,
    required this.totalVotes,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String text;
  final int count;
  final int totalVotes;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percentage = totalVotes > 0 ? (count / totalVotes) : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFFF2D55) : Colors.white24,
            ),
            color: const Color(0xFF161616),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage.clamp(0.0, 1.0).toDouble(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x33FF2D55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Text(
                      '$count',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PollsErrorState extends StatelessWidget {
  const _PollsErrorState({
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
