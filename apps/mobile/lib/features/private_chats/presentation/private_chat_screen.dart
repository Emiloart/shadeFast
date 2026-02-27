import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/private_chat_edge_functions.dart';
import '../domain/private_chat.dart';

class PrivateChatScreen extends ConsumerWidget {
  const PrivateChatScreen({
    required this.token,
    super.key,
  });

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(joinPrivateChatProvider(token));

    return Scaffold(
      appBar: AppBar(title: const Text('Private Chat')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => _JoinErrorState(
          message: 'Could not join private chat: $error',
          onRetry: () => ref.invalidate(joinPrivateChatProvider(token)),
        ),
        data: (PrivateChatSession session) =>
            _PrivateChatRoom(session: session),
      ),
    );
  }
}

class _PrivateChatRoom extends ConsumerStatefulWidget {
  const _PrivateChatRoom({
    required this.session,
  });

  final PrivateChatSession session;

  @override
  ConsumerState<_PrivateChatRoom> createState() => _PrivateChatRoomState();
}

class _PrivateChatRoomState extends ConsumerState<_PrivateChatRoom> {
  final _messageController = TextEditingController();
  bool _isSending = false;
  bool _isReadOnceLoading = false;
  Timer? _readOnceTimer;
  final List<PrivateChatMessage> _readOnceMessages = <PrivateChatMessage>[];

  @override
  void initState() {
    super.initState();
    if (widget.session.readOnce) {
      _startReadOncePolling();
    }
  }

  @override
  void didUpdateWidget(covariant _PrivateChatRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.id != oldWidget.session.id) {
      _readOnceMessages.clear();
    }
    if (widget.session.readOnce &&
        (!oldWidget.session.readOnce ||
            widget.session.id != oldWidget.session.id)) {
      _startReadOncePolling();
    }
  }

  @override
  void dispose() {
    _readOnceTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _startReadOncePolling() {
    _readOnceTimer?.cancel();
    _pollReadOnceMessages();
    _readOnceTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollReadOnceMessages(),
    );
  }

  Future<void> _pollReadOnceMessages() async {
    if (!widget.session.readOnce || _isReadOnceLoading || !mounted) {
      return;
    }

    final api = ref.read(privateChatEdgeFunctionsProvider);
    if (api == null) {
      return;
    }

    _isReadOnceLoading = true;
    try {
      final incoming = await api.readMessagesOnce(widget.session.id);
      if (incoming.isEmpty || !mounted) {
        return;
      }

      setState(() {
        _mergeReadOnceMessages(incoming);
      });
    } catch (_) {
      // Ignore transient poll errors; next poll will retry.
    } finally {
      _isReadOnceLoading = false;
    }
  }

  void _mergeReadOnceMessages(List<PrivateChatMessage> messages) {
    final seenIds = _readOnceMessages
        .map((PrivateChatMessage message) => message.id)
        .toSet();
    for (final message in messages) {
      if (!seenIds.contains(message.id)) {
        _readOnceMessages.add(message);
      }
    }
    _readOnceMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }

    final api = ref.read(privateChatEdgeFunctionsProvider);
    if (api == null) {
      return;
    }

    final body = _messageController.text.trim();
    if (body.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await api.sendMessage(
        privateChatId: widget.session.id,
        body: body,
      );
      _messageController.clear();

      if (widget.session.readOnce) {
        setState(() {
          _readOnceMessages.add(
            PrivateChatMessage(
              id: 'local-${DateTime.now().microsecondsSinceEpoch}',
              privateChatId: widget.session.id,
              senderUuid: api.currentUserId ?? 'self',
              body: body,
              createdAt: DateTime.now().toUtc().toIso8601String(),
              expiresAt: widget.session.expiresAt,
            ),
          );
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $error')),
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
    final api = ref.watch(privateChatEdgeFunctionsProvider);
    final currentUserId = api?.currentUserId;

    return SafeArea(
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Link expires in ${_timeUntil(widget.session.expiresAt)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (widget.session.readOnce)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Read-once mode is enabled.',
                      style: TextStyle(
                        color: Color(0xFFFF2D55),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: widget.session.readOnce
                ? _MessageList(
                    messages: _readOnceMessages,
                    currentUserId: currentUserId,
                  )
                : _LiveMessageList(
                    privateChatId: widget.session.id,
                    currentUserId: currentUserId,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: 'Write a message...',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : _sendMessage,
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
          ),
        ],
      ),
    );
  }
}

class _LiveMessageList extends ConsumerWidget {
  const _LiveMessageList({
    required this.privateChatId,
    required this.currentUserId,
  });

  final String privateChatId;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(privateChatMessagesProvider(privateChatId));

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load messages: $error',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (List<PrivateChatMessage> messages) => _MessageList(
        messages: messages,
        currentUserId: currentUserId,
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentUserId,
  });

  final List<PrivateChatMessage> messages;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet. Say something.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messages.length,
      itemBuilder: (_, int index) {
        final message = messages[index];
        final isMine =
            currentUserId != null && currentUserId == message.senderUuid;

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMine ? const Color(0x33FF2D55) : const Color(0xFF171717),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.body,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _compactTime(message.createdAt),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JoinErrorState extends StatelessWidget {
  const _JoinErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
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

String _timeUntil(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final now = DateTime.now().toUtc();
  final diff = parsed.toUtc().difference(now);
  if (diff.isNegative) {
    return 'expired';
  }
  if (diff.inMinutes < 1) {
    return '<1m';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m';
  }

  return '${diff.inHours}h ${diff.inMinutes % 60}m';
}
