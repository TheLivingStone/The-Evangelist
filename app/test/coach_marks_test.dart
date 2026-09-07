import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_evangelist/core/coach_marks.dart';
import 'package:the_evangelist/core/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app(GlobalKey key) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: ElevatedButton(
          key: key,
          onPressed: () {},
          child: const Text('Go'),
        ),
      ),
    ),
  );

  testWidgets('shows once around the target and is dismissed by Got it', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(app(key));
    final context = tester.element(find.text('Go'));

    final first = CoachMarks.show(
      context,
      id: 'test',
      target: key,
      title: 'Start here',
      text: 'Tap this button.',
      delay: Duration.zero,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('Tap this button.'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await first;
    expect(find.text('Tap this button.'), findsNothing);
    expect(await CoachMarks.seen('test'), isTrue);

    // Second time: already seen, nothing appears.
    await CoachMarks.show(
      context,
      id: 'test',
      target: key,
      text: 'Tap this button.',
      delay: Duration.zero,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tap this button.'), findsNothing);
  });

  testWidgets('does nothing when the target is not on screen', (tester) async {
    await tester.pumpWidget(app(GlobalKey()));
    final context = tester.element(find.text('Go'));
    // Not awaited directly: the delay is a timer, and timers only fire when
    // the test pumps.
    final call = CoachMarks.show(
      context,
      id: 'missing',
      target: GlobalKey(),
      text: 'never',
      delay: Duration.zero,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await call;
    expect(find.text('never'), findsNothing);
    expect(await CoachMarks.seen('missing'), isFalse);
  });
}
