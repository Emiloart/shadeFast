import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/community_edge_functions.dart';
import '../domain/community.dart';

class JoinLinkScreen extends ConsumerWidget {
  const JoinLinkScreen({
    required this.joinCode,
    super.key,
  });

  final String joinCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joinRequest = ref.watch(joinCommunityByCodeProvider(joinCode));

    return Scaffold(
      appBar: AppBar(title: const Text('Joining Community')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: joinRequest.when(
            loading: () => const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Joining by invite link...'),
              ],
            ),
            error: (Object error, StackTrace _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Could not join: $error',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(
                    joinCommunityByCodeProvider(joinCode),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (Community community) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF2DD4BF),
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  'Joined ${community.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/community/${community.id}'),
                  child: const Text('Open Community'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
