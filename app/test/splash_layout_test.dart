import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_evangelist/core/brand.dart';
import 'package:the_evangelist/features/shell/splash_screen.dart';

/// Regression: the splash lockup once rendered flush-left (half off-screen) on
/// an iPhone because Scaffold lays its body out with loose width constraints.
void main() {
  testWidgets('splash lockup is centred at phone width', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: BrandSplash()));
    await tester.pump(const Duration(milliseconds: 50));

    final lockup = tester.getRect(find.byType(BrandLockup));
    expect(lockup.center.dx, closeTo(393 / 2, 1.0));
    expect(lockup.left, greaterThanOrEqualTo(0));
    expect(lockup.right, lessThanOrEqualTo(393));

    final bar = tester.getRect(find.byType(LinearProgressIndicator));
    expect(bar.center.dx, closeTo(393 / 2, 1.0));
  });
}
