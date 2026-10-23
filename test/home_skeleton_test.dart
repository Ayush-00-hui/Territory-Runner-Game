import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/home/home_screen.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  testWidgets(
    'HomeScreen renders skeleton fallback when Hive boxes are not open',
    (tester) async {
      // In this test file, Hive boxes ('profile' and 'territories_v3') are not opened.
      // HomeScreen must safely catch this and render athletic SkeletonBox elements without crashing.
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(isActive: false)),
      );
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);

      // Clean up to stop any running tickers
      await tester.pumpWidget(const SizedBox());
    },
  );
}
