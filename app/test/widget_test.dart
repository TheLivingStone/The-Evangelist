import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_evangelist/core/theme.dart';

void main() {
  testWidgets('App theme builds and renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('The Evangelist'))),
      ),
    );
    expect(find.text('The Evangelist'), findsOneWidget);
  });
}
