import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/performance/app_performance_tracker.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class ShadeFastApp extends ConsumerStatefulWidget {
  const ShadeFastApp({super.key});

  @override
  ConsumerState<ShadeFastApp> createState() => _ShadeFastAppState();
}

class _ShadeFastAppState extends ConsumerState<ShadeFastApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appPerformanceTrackerProvider).trackAppFirstFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ShadeFast',
      theme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
