import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_bootstrap_provider.dart';
import '../../auth/domain/auth_bootstrap_state.dart';
import '../../communities/data/community_edge_functions.dart';
import '../../communities/domain/community.dart';
import '../../communities/presentation/create_community_dialog.dart';
import '../../communities/presentation/join_community_dialog.dart';
import '../../experiments/application/experiment_providers.dart';
import '../../experiments/data/experiment_edge_functions.dart';
import '../../private_chats/data/private_chat_edge_functions.dart';
import '../../private_chats/domain/private_chat.dart';
import '../../private_chats/presentation/create_private_chat_link_dialog.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authBootstrap = ref.watch(authBootstrapProvider);
    final featureFlags = ref.watch(featureFlagSnapshotProvider).valueOrNull;
    final sponsoredTemplatesEnabled =
        featureFlags?.isEnabled('sponsored_templates', fallback: true) ?? true;
    final premiumEntryEnabled =
        featureFlags?.isEnabled('premium_entry', fallback: true) ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('ShadeFast')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 24),
              const Text(
                'Throw shade. No one knows it\'s you.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose your first community or browse Global Hot.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              authBootstrap.when(
                loading: () => const _StatusPanel(
                  message: 'Initializing anonymous session...',
                ),
                error: (_, __) => const _StatusPanel(
                  message:
                      'Auth bootstrap failed. Check Supabase settings and retry.',
                ),
                data: (AuthBootstrapState state) {
                  if (state.status == AuthBootstrapStatus.ready) {
                    return _StatusPanel(
                      message:
                          'Anonymous session ready (${state.userId?.substring(0, 8)}...)',
                    );
                  }

                  return _StatusPanel(
                    message: state.message ?? 'Backend is not configured.',
                    isWarning: true,
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/global'),
                child: const Text('Browse Global Hot'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: authBootstrap.maybeWhen(
                  data: (AuthBootstrapState state) => state.isReady
                      ? () => _showCreateCommunityDialog(
                            context,
                            ref,
                            useSponsoredTemplates: sponsoredTemplatesEnabled,
                          )
                      : null,
                  orElse: () => null,
                ),
                child: const Text('Create Community'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: authBootstrap.maybeWhen(
                  data: (AuthBootstrapState state) => state.isReady
                      ? () => _showJoinCommunityDialog(context, ref)
                      : null,
                  orElse: () => null,
                ),
                child: const Text('Join by Code'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: authBootstrap.maybeWhen(
                  data: (AuthBootstrapState state) => state.isReady
                      ? () => _showCreatePrivateChatLink(context, ref)
                      : null,
                  orElse: () => null,
                ),
                child: const Text('Create Private Link'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: authBootstrap.maybeWhen(
                  data: (AuthBootstrapState state) =>
                      state.isReady ? () => context.push('/polls') : null,
                  orElse: () => null,
                ),
                child: const Text('Trending Polls'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: authBootstrap.maybeWhen(
                  data: (AuthBootstrapState state) =>
                      state.isReady ? () => context.push('/challenges') : null,
                  orElse: () => null,
                ),
                child: const Text('Trending Challenges'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: authBootstrap.maybeWhen(
                  data: (AuthBootstrapState state) => state.isReady
                      ? () => context.push('/notifications')
                      : null,
                  orElse: () => null,
                ),
                child: const Text('Notifications'),
              ),
              if (premiumEntryEnabled) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: authBootstrap.maybeWhen(
                    data: (AuthBootstrapState state) =>
                        state.isReady ? () => context.push('/premium') : null,
                    orElse: () => null,
                  ),
                  child: const Text('Premium'),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.push('/legal'),
                child: const Text('Terms, Privacy, Community Guidelines'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCreateCommunityDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool useSponsoredTemplates,
}) async {
  final api = ref.read(communityEdgeFunctionsProvider);
  if (api == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supabase is not configured.')),
    );
    return;
  }

  List<SponsoredCommunityTemplate> templates =
      const <SponsoredCommunityTemplate>[];
  if (useSponsoredTemplates) {
    try {
      templates = await api.listSponsoredCommunityTemplates(limit: 20);
    } catch (_) {
      // Fallback silently to custom creation if template fetch fails.
    }
  }

  await _trackExperimentEvent(
    ref,
    eventName: 'onboarding_create_community_open',
    properties: <String, dynamic>{
      'sponsoredTemplatesEnabled': useSponsoredTemplates,
      'templateCount': templates.length,
    },
  );

  if (!context.mounted) {
    return;
  }

  final result = await showDialog<CreateCommunityDialogResult>(
    context: context,
    builder: (_) => CreateCommunityDialog(templates: templates),
  );

  if (result == null) {
    return;
  }

  try {
    final community = await api.createCommunity(
      name: result.name,
      description: result.description,
      category: result.category,
      isPrivate: result.isPrivate,
      templateId: result.templateId,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Created ${community.name}. Join code: ${community.joinCode}',
        ),
      ),
    );

    context.go('/community/${community.id}');
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Create failed: $error')),
    );
  }
}

Future<void> _showJoinCommunityDialog(
    BuildContext context, WidgetRef ref) async {
  final api = ref.read(communityEdgeFunctionsProvider);
  if (api == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supabase is not configured.')),
    );
    return;
  }

  final joinCode = await showDialog<String>(
    context: context,
    builder: (_) => const JoinCommunityDialog(),
  );

  if (joinCode == null) {
    return;
  }

  try {
    final community = await api.joinCommunity(joinCode: joinCode);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joined ${community.name}.')),
    );

    context.go('/community/${community.id}');
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Join failed: $error')),
    );
  }
}

Future<void> _showCreatePrivateChatLink(
  BuildContext context,
  WidgetRef ref,
) async {
  final api = ref.read(privateChatEdgeFunctionsProvider);
  if (api == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supabase is not configured.')),
    );
    return;
  }

  final options = await showDialog<CreatePrivateChatLinkDialogResult>(
    context: context,
    builder: (_) => const CreatePrivateChatLinkDialog(),
  );

  if (options == null) {
    return;
  }

  try {
    final link = await api.createPrivateChatLink(
      readOnce: options.readOnce,
      ttlMinutes: options.ttlMinutes,
    );

    await Clipboard.setData(ClipboardData(text: link.webLink));

    if (!context.mounted) {
      return;
    }

    await _showPrivateLinkCreatedDialog(context, link);

    if (!context.mounted) {
      return;
    }

    context.go('/chat/${link.chat.token}');
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    final message = error is PrivateChatApiException
        ? error.message
        : 'Private link failed: $error';
    final requiresPremium =
        error is PrivateChatApiException && error.code == 'premium_required';
    if (requiresPremium) {
      await _trackExperimentEvent(
        ref,
        eventName: 'private_link_premium_required',
        properties: const <String, dynamic>{
          'source': 'onboarding',
        },
      );
      if (!context.mounted) {
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          requiresPremium ? message : 'Private link failed: $message',
        ),
        action: requiresPremium
            ? SnackBarAction(
                label: 'Premium',
                onPressed: () {
                  if (context.mounted) {
                    context.push('/premium');
                  }
                },
              )
            : null,
      ),
    );
  }
}

Future<void> _trackExperimentEvent(
  WidgetRef ref, {
  required String eventName,
  Map<String, dynamic>? properties,
}) async {
  final api = ref.read(experimentEdgeFunctionsProvider);
  if (api == null) {
    return;
  }

  try {
    await api.trackExperimentEvent(
      eventName: eventName,
      properties: properties,
      platform: 'mobile',
    );
  } catch (_) {
    // Ignore instrumentation failures in onboarding UX flows.
  }
}

Future<void> _showPrivateLinkCreatedDialog(
  BuildContext context,
  PrivateChatLink link,
) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Private Link Ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Link copied to clipboard.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            SelectableText(
              link.webLink,
              style: const TextStyle(
                color: Color(0xFFFF2D55),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Expires at ${link.chat.expiresAt}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Open Chat'),
          ),
        ],
      );
    },
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.message,
    this.isWarning = false,
  });

  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isWarning ? const Color(0xFFFFB020) : const Color(0xFF2DD4BF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        message,
        style:
            TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
      ),
    );
  }
}
