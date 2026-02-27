import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/auth_bootstrap_state.dart';

final authBootstrapProvider = FutureProvider<AuthBootstrapState>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  if (client == null) {
    return const AuthBootstrapState.missingConfig();
  }

  try {
    var session = client.auth.currentSession;

    if (session == null) {
      final response = await client.auth.signInAnonymously();
      session = response.session;
    }

    final userId = session?.user.id;
    if (userId == null || userId.isEmpty) {
      return const AuthBootstrapState.error(
        'Anonymous session is not available. Check Auth settings in Supabase.',
      );
    }

    return AuthBootstrapState.ready(userId);
  } catch (_) {
    return const AuthBootstrapState.error(
      'Failed to initialize anonymous session.',
    );
  }
});
