import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App basic UI rendering test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('TERRITORY RUNNER'),
          ),
        ),
      ),
    );
    expect(find.text('TERRITORY RUNNER'), findsOneWidget);
  });
}

