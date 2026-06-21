import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:the_evangelist/main.dart';
import 'package:the_evangelist/repositories/repositories.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetLocalData);

  testWidgets('dashboard to completed outreach session', (tester) async {
    await tester.pumpWidget(const ProviderScopedApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Hi, Evangelist'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Outreach Session'));
    await tester.pumpAndSettle();

    expect(find.text('Outreach Live'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add).at(0));
    await tester.tap(find.byIcon(Icons.add).at(1));
    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();

    expect(find.text('Session Complete 🎉'), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Prayers'), findsOneWidget);
  });
}
