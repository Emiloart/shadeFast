import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/app_supabase.dart';
import 'core/telemetry/app_telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSupabase.initialize();

  final client = AppSupabase.client;
  final telemetry = client == null ? null : AppTelemetry(client);
  _registerGlobalErrorTelemetry(telemetry);

  runApp(const ProviderScope(child: ShadeFastApp()));
}

void _registerGlobalErrorTelemetry(AppTelemetry? telemetry) {
  if (telemetry == null) {
    return;
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    telemetry.trackEventInBackground(
      eventName: 'app_unhandled_flutter_error',
      properties: <String, Object?>{
        'exceptionType': details.exception.runtimeType.toString(),
      },
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    telemetry.trackEventInBackground(
      eventName: 'app_unhandled_platform_error',
      properties: <String, Object?>{
        'exceptionType': error.runtimeType.toString(),
      },
    );

    return false;
  };
}
