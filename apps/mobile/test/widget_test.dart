import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadefast_mobile/app.dart';

void main() {
  testWidgets('app boots to onboarding shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ShadeFastApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ShadeFast'), findsOneWidget);
    expect(find.textContaining('Throw shade.'), findsOneWidget);
  });
}
