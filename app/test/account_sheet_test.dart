import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_evangelist/core/auth_account.dart';
import 'package:the_evangelist/core/theme.dart';

/// The account sheet overflowed with the keyboard up (45px, then 18px after a
/// partial fix). It must fit on the smallest supported phone with a tall
/// keyboard, and again at the largest text size.
void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required Size size,
    required double keyboard,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              viewInsets: EdgeInsets.only(bottom: keyboard),
              padding: const EdgeInsets.only(top: 47, bottom: 34),
              textScaler: TextScaler.linear(textScale),
            ),
            // Match how the app presents it: a modal bottom sheet route,
            // which is what gives the sheet its box.
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const UpgradeAccountSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('fits on a small phone with the keyboard up', (tester) async {
    // iPhone SE-class logical size, typical iOS keyboard height.
    await pumpSheet(tester, size: const Size(375, 667), keyboard: 336);
    expect(tester.takeException(), isNull);
    expect(find.text('Save & continue'), findsOneWidget);
  });

  testWidgets('fits on a large phone with the keyboard up', (tester) async {
    await pumpSheet(tester, size: const Size(430, 932), keyboard: 346);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits at the largest supported text size', (tester) async {
    await pumpSheet(
      tester,
      size: const Size(375, 667),
      keyboard: 336,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
