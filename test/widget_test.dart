import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_reminder_app/screens/add_bill_screen.dart';

void main() {
  testWidgets('Add bill screen renders expected form fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AddBillScreen()),
    );

    expect(find.text('Add Bill'), findsOneWidget);
    expect(find.text('Bill Name'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Pick Date'), findsOneWidget);
    expect(find.text('Save Bill'), findsOneWidget);
  });
}
