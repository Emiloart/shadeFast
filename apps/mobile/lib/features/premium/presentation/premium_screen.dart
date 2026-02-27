import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/premium_providers.dart';
import '../data/premium_edge_functions.dart';
import '../domain/premium_models.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _activatingTrial = false;

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(premiumSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => _PremiumErrorState(
          message: 'Failed to load premium data: $error',
          onRetry: () => ref.invalidate(premiumSnapshotProvider),
        ),
        data: (PremiumSnapshot snapshot) {
          final active = snapshot.activePremiumEntitlement;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _PremiumStatusCard(
                  activeEntitlement: active,
                  hasPremium: snapshot.hasActivePremium,
                ),
                const SizedBox(height: 10),
                if (!snapshot.hasActivePremium)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Try Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Activate a one-time 3-day trial to unlock higher private-link limits.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed:
                                _activatingTrial ? null : _activatePremiumTrial,
                            icon: _activatingTrial
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.bolt_outlined),
                            label: Text(
                              _activatingTrial
                                  ? 'Activating...'
                                  : 'Activate 3-day Trial',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Plans',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...snapshot.products.map((SubscriptionProduct product) {
                          final isCurrent = active?.productId == product.id;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isCurrent
                                  ? Icons.verified_outlined
                                  : Icons.workspace_premium_outlined,
                              color: isCurrent
                                  ? const Color(0xFF2DD4BF)
                                  : const Color(0xFFFF2D55),
                            ),
                            title: Text(
                              product.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              product.description ?? 'No description available.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: isCurrent
                                ? const Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Color(0xFF2DD4BF),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(premiumSnapshotProvider);
    await ref.read(premiumSnapshotProvider.future);
  }

  Future<void> _activatePremiumTrial() async {
    final api = ref.read(premiumEdgeFunctionsProvider);
    if (api == null) {
      _showSnackBar('Supabase is not configured.');
      return;
    }

    setState(() {
      _activatingTrial = true;
    });

    try {
      await api.activatePremiumTrial(days: 3);

      if (!mounted) {
        return;
      }

      ref.invalidate(premiumSnapshotProvider);
      _showSnackBar('Premium trial activated.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Trial activation failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _activatingTrial = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PremiumStatusCard extends StatelessWidget {
  const _PremiumStatusCard({
    required this.activeEntitlement,
    required this.hasPremium,
  });

  final UserEntitlement? activeEntitlement;
  final bool hasPremium;

  @override
  Widget build(BuildContext context) {
    final expiresAt = activeEntitlement?.expiresAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(
              hasPremium
                  ? Icons.workspace_premium
                  : Icons.workspace_premium_outlined,
              color: hasPremium ? const Color(0xFF2DD4BF) : const Color(0xFFFF2D55),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasPremium
                    ? 'Premium active${expiresAt != null ? ' until ${_formatTimestamp(expiresAt)}' : ''}.'
                    : 'You are on free tier. Premium unlocks higher private-link limits.',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumErrorState extends StatelessWidget {
  const _PremiumErrorState({
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

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final date = '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
