import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notification_providers.dart';
import '../data/notification_edge_functions.dart';
import '../domain/notification_event.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _updatingToken = false;

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(notificationFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.invalidate(notificationFeedProvider),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => _NotificationErrorState(
          message: 'Failed to load notifications: $error',
          onRetry: () => ref.invalidate(notificationFeedProvider),
        ),
        data: (NotificationFeedPage page) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _QueueStatusCard(undeliveredCount: page.undeliveredCount),
                const SizedBox(height: 10),
                if (page.events.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'No notifications yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                else
                  ...page.events.map(_NotificationTile.new),
                const SizedBox(height: 16),
                _TokenToolsCard(
                  isUpdating: _updatingToken,
                  onRegister: _registerDebugToken,
                  onUnregister: _unregisterDebugToken,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(notificationFeedProvider);
    await ref.read(notificationFeedProvider.future);
  }

  Future<void> _registerDebugToken() async {
    final api = ref.read(notificationEdgeFunctionsProvider);
    if (api == null) {
      _showSnackBar('Supabase is not configured.');
      return;
    }

    final result = await showDialog<_TokenInputResult>(
      context: context,
      builder: (_) => const _TokenInputDialog(),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _updatingToken = true;
    });

    try {
      await api.registerPushToken(
        token: result.token,
        platform: result.platform,
      );

      if (!mounted) {
        return;
      }

      _showSnackBar('Push token registered.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Register token failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _updatingToken = false;
        });
      }
    }
  }

  Future<void> _unregisterDebugToken() async {
    final api = ref.read(notificationEdgeFunctionsProvider);
    if (api == null) {
      _showSnackBar('Supabase is not configured.');
      return;
    }

    setState(() {
      _updatingToken = true;
    });

    try {
      await api.unregisterPushToken();

      if (!mounted) {
        return;
      }

      _showSnackBar('Active push tokens revoked.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Unregister token failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _updatingToken = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _QueueStatusCard extends StatelessWidget {
  const _QueueStatusCard({required this.undeliveredCount});

  final int undeliveredCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.notifications_active_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                undeliveredCount == 0
                    ? 'Delivery queue is clear.'
                    : '$undeliveredCount notification(s) pending delivery.',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.event);

  final NotificationEvent event;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(event.eventType);
    final text = _messageForEvent(event);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(icon, color: const Color(0xFFFF2D55)),
        title: Text(
          text.title,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${text.body}\n${_formatTimestamp(event.createdAt)}',
          style: const TextStyle(color: Colors.white70),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _TokenToolsCard extends StatelessWidget {
  const _TokenToolsCard({
    required this.isUpdating,
    required this.onRegister,
    required this.onUnregister,
  });

  final bool isUpdating;
  final VoidCallback onRegister;
  final VoidCallback onUnregister;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Push Token Tools',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use for dev/testing until automated native token registration is wired.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: isUpdating ? null : onRegister,
                  icon: isUpdating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.app_registration_outlined),
                  label: const Text('Register Token'),
                ),
                OutlinedButton.icon(
                  onPressed: isUpdating ? null : onUnregister,
                  icon: const Icon(Icons.notifications_off_outlined),
                  label: const Text('Revoke My Tokens'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationErrorState extends StatelessWidget {
  const _NotificationErrorState({
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

class _TokenInputResult {
  const _TokenInputResult({
    required this.token,
    required this.platform,
  });

  final String token;
  final String platform;
}

class _TokenInputDialog extends StatefulWidget {
  const _TokenInputDialog();

  @override
  State<_TokenInputDialog> createState() => _TokenInputDialogState();
}

class _TokenInputDialogState extends State<_TokenInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  String _platform = 'android';

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: const Text('Register Push Token'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _platform,
                decoration: const InputDecoration(labelText: 'Platform'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'android', child: Text('Android')),
                  DropdownMenuItem(value: 'ios', child: Text('iOS')),
                  DropdownMenuItem(value: 'web', child: Text('Web')),
                ],
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _platform = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tokenController,
                maxLength: 4096,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Push token',
                ),
                validator: (String? value) {
                  final token = value?.trim() ?? '';
                  if (token.length < 16) {
                    return 'Enter a valid token.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop(
              _TokenInputResult(
                token: _tokenController.text.trim(),
                platform: _platform,
              ),
            );
          },
          child: const Text('Register'),
        ),
      ],
    );
  }
}

IconData _iconForType(String eventType) {
  switch (eventType) {
    case 'reply':
      return Icons.reply_outlined;
    case 'reaction':
      return Icons.favorite_outline;
    case 'challenge_entry':
      return Icons.flag_outlined;
    default:
      return Icons.notifications_none;
  }
}

({String title, String body}) _messageForEvent(NotificationEvent event) {
  switch (event.eventType) {
    case 'reply':
      return (
        title: 'New reply',
        body: event.payload?['preview'] is String
            ? 'Someone replied: ${event.payload!['preview'] as String}'
            : 'Someone replied to your post.',
      );
    case 'reaction':
      return (
        title: 'New reaction',
        body: 'Someone reacted to your post.',
      );
    case 'challenge_entry':
      return (
        title: 'Challenge update',
        body: 'A new entry was submitted to your challenge.',
      );
    default:
      return (
        title: event.payload?['title'] as String? ?? 'Notification',
        body: event.payload?['body'] as String? ?? 'You have an update.',
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
