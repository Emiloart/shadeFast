import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_supabase.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return AppSupabase.client;
});
