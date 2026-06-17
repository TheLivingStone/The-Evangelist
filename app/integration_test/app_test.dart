// End-to-end integration test driving the real app against the live Supabase
// backend. Creates a fresh user, signs up, logs an outreach, and verifies the
// dashboard reflects it.
//
// Run:
//   flutter test integration_test/app_test.dart -d emulator-5554 \
//     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:the_evangelist/core/supabase.dart';
import 'package:the_evangelist/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signup → dashboard → log conversation → streak updates',
      (tester) async {
    await initSupabase();
    // ensure a clean session
    await supabase.auth.signOut();

    await tester.pumpWidget(const ProviderScopedApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // We should be on the auth screen
    expect(find.text('The Evangelist'), findsWidgets);

    final email = 'e2e_${DateTime.now().millisecondsSinceEpoch}@example.com';

    // Fill the sign-up form (Full name, Email, Password)
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'E2E Tester');
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), 'password123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Now on the dashboard — greeting visible
    expect(find.textContaining('Hi,'), findsOneWidget);
    expect(find.text('Weekly Mission'), findsOneWidget);
    expect(find.text('Impact This Month'), findsOneWidget);

    // Open the ➕ Start sheet and log a conversation
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('What happened today?'), findsOneWidget);
    await tester.tap(find.text('Log Conversation'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify in the backend that the streak is now 1
    final me = await supabase
        .from('profiles')
        .select('current_streak, total_conversations')
        .eq('id', supabase.auth.currentUser!.id)
        .single();
    expect(me['current_streak'], 1);
    expect(me['total_conversations'], greaterThanOrEqualTo(1));

    // Clean up: delete the activity + this user's data via cascade is not
    // possible from client; leaving the test user is acceptable for CI.
  });
}
