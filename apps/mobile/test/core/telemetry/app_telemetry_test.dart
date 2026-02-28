import 'package:flutter_test/flutter_test.dart';

import 'package:shadefast_mobile/core/telemetry/app_telemetry.dart';

void main() {
  group('sanitizeTelemetryProperties', () {
    test('keeps only safe keys and primitive values', () {
      final sanitized = sanitizeTelemetryProperties(
        <String, Object?>{
          'safe_key': 'value',
          'boolFlag': true,
          'count': 42,
          'bad-key': 'drop',
          '': 'drop',
          'nested': <String, Object?>{'x': 1},
        },
      );

      expect(
        sanitized,
        <String, dynamic>{
          'safe_key': 'value',
          'boolFlag': true,
          'count': 42,
        },
      );
    });

    test('trims and truncates long strings', () {
      final longText = 'x' * 300;
      final sanitized = sanitizeTelemetryProperties(
        <String, Object?>{
          'long': longText,
        },
      );

      expect((sanitized['long'] as String).length, 160);
    });

    test('sanitizes list values into short string arrays', () {
      final sanitized = sanitizeTelemetryProperties(
        <String, Object?>{
          'list': <Object?>[
            ' alpha ',
            1,
            true,
            null,
            'beta',
          ],
        },
      );

      expect(
        sanitized,
        <String, dynamic>{
          'list': <String>['alpha', 'beta'],
        },
      );
    });
  });
}
