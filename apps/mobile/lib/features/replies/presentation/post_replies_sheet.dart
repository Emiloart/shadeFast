import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/reply_thread_controller.dart';
import '../domain/reply.dart';

class PostRepliesSheet extends ConsumerStatefulWidget {
  const PostRepliesSheet({
    required this.postId,
    super.key,
  });

  final String postId;

  @override
  ConsumerState<PostRepliesSheet> createState() => _PostRepliesSheetState();
}

class _PostRepliesSheetState extends ConsumerState<PostRepliesSheet> {
  final _controller = TextEditingController();
  bool _isSending = false;
  String? _parentReplyId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    if (_isSending) {
      return;
    }

    final body = _controller.text.trim();
    if (body.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await ref
          .read(replyThreadControllerProvider(widget.postId).notifier)
          .createReply(
            body: body,
            parentReplyId: _parentReplyId,
          );

      _controller.clear();
      if (!mounted) {
        return;
      }

      setState(() {
        _parentReplyId = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reply failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repliesAsync =
        ref.watch(replyThreadControllerProvider(widget.postId));
    final replies = repliesAsync.valueOrNull ?? const <ShadeReply>[];
    final replyById = <String, ShadeReply>{
      for (final reply in replies) reply.id: reply,
    };

    final parentReply =
        _parentReplyId == null ? null : replyById[_parentReplyId];
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Replies',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref
                          .read(replyThreadControllerProvider(widget.postId)
                              .notifier)
                          .refresh();
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              if (parentReply != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Replying to ${_anonymousAlias(parentReply.userUuid)}',
                          style: const TextStyle(
                            color: Color(0xFFFF2D55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _parentReplyId = null;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: repliesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Failed to load replies: $error',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              ref.invalidate(
                                replyThreadControllerProvider(widget.postId),
                              );
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (List<ShadeReply> data) {
                    if (data.isEmpty) {
                      return const Center(
                        child: Text(
                          'No replies yet. Start the thread.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, int index) {
                        final reply = data[index];
                        final depth = _threadDepth(reply, replyById);
                        final parent = reply.parentReplyId == null
                            ? null
                            : replyById[reply.parentReplyId];

                        return _ReplyCard(
                          reply: reply,
                          depth: depth,
                          parent: parent,
                          isReplyingTarget: _parentReplyId == reply.id,
                          onTapReply: () {
                            setState(() {
                              _parentReplyId = reply.id;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1500,
                      decoration: const InputDecoration(
                        hintText: 'Write an anonymous reply...',
                        counterText: '',
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _submitReply,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.reply,
    required this.depth,
    required this.parent,
    required this.isReplyingTarget,
    required this.onTapReply,
  });

  final ShadeReply reply;
  final int depth;
  final ShadeReply? parent;
  final bool isReplyingTarget;
  final VoidCallback onTapReply;

  @override
  Widget build(BuildContext context) {
    final leftMargin = depth * 12.0;
    final borderColor =
        isReplyingTarget ? const Color(0xFFFF2D55) : Colors.white12;

    return Container(
      margin: EdgeInsets.only(left: leftMargin),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (parent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '↳ ${_anonymousAlias(parent!.userUuid)}',
                style: const TextStyle(
                  color: Color(0xFFFF2D55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            reply.body,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                _anonymousAlias(reply.userUuid),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                _compactTime(reply.createdAt),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: onTapReply,
                child: const Text('Reply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

int _threadDepth(ShadeReply reply, Map<String, ShadeReply> replyById) {
  var depth = 0;
  var parentId = reply.parentReplyId;

  while (parentId != null && depth < 3) {
    final parent = replyById[parentId];
    if (parent == null) {
      break;
    }
    depth += 1;
    parentId = parent.parentReplyId;
  }

  return depth;
}

String _anonymousAlias(String userUuid) {
  final value = userUuid.replaceAll('-', '');
  final suffix = value.length >= 6 ? value.substring(0, 6) : value;
  return 'anon-$suffix';
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
