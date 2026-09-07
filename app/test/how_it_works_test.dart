import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_evangelist/core/theme.dart';
import 'package:the_evangelist/features/onboarding/how_it_works_screen.dart';

void main() {
  testWidgets('the tour has seven steps and closes on the button', (
    tester,
  ) async {
    expect(HowItWorksScreen.steps, hasLength(7));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Text('home')),
        routes: {'/tour': (_) => const HowItWorksScreen(firstRun: true)},
      ),
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed('/tour');
    await tester.pumpAndSettle();

    expect(find.text('STEP 1'), findsOneWidget);
    expect(find.text('Tap the orange + button'), findsOneWidget);

    final button = find.text("Let's go");
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('STEP 7'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('STEP 1'), findsNothing);
  });
}
