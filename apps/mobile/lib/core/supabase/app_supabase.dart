import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class AppSupabase {
  AppSupabase._();

  static SupabaseClient? _client;
  static bool _initialized = false;

  static SupabaseClient? get client => _client;

  static Future<void> initialize() async {
    if (_initialized || !AppEnv.isSupabaseConfigured) {
      return;
    }

    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    );

    _client = Supabase.instance.client;
    _initialized = true;
  }
}
