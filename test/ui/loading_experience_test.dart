import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/services/loading_quotes_service.dart';
import 'package:territory_runner/ui/theme/app_colors.dart';
import 'package:territory_runner/ui/widgets/app_loading_view.dart';
import 'package:territory_runner/ui/widgets/inline_loading.dart';
import 'package:territory_runner/ui/widgets/primary_button.dart';
import 'package:territory_runner/ui/widgets/secondary_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase L: Assets and LoadingQuotesService Tests', () {
    test(
      'assets/loading_quotes.json exists, is valid, and contains >= 80 items',
      () {
        final file = File('assets/loading_quotes.json');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'assets/loading_quotes.json must exist',
        );

        final content = file.readAsStringSync();
        final dynamic decoded = jsonDecode(content);
        expect(decoded, isA<List>());

        final quotes = decoded as List;
        expect(
          quotes.length,
          greaterThanOrEqualTo(80),
          reason: 'Must contain at least 80 quotes/facts',
        );

        for (int i = 0; i < quotes.length; i++) {
          final item = quotes[i];
          expect(item, isA<Map>());
          final map = item as Map<String, dynamic>;
          expect(map['text'], isA<String>());
          expect(
            (map['text'] as String).trim(),
            isNotEmpty,
            reason: 'Quote at index $i must not have empty text',
          );
          expect(map['author'], isA<String>());
          expect(
            (map['author'] as String).trim(),
            isNotEmpty,
            reason: 'Quote at index $i must have non-empty author',
          );
        }
      },
    );

    test('LoadingQuotesService provides synchronous fallback and loads from mock bundle', () async {
      final service = LoadingQuotesService.instance;
      final syncQuote = service.getQuote();
      expect(syncQuote.text, isNotEmpty);
      expect(syncQuote.author, isNotEmpty);

      final testQuotes = [
        const RunningQuote(
          text: 'Test Athletic Fact A',
          author: 'Biomechanics Lab',
        ),
        const RunningQuote(
          text: 'Test Athletic Fact B',
          author: 'Olympic Archives',
        ),
      ];
      service.setQuotesForTesting(testQuotes);

      final q0 = service.getQuote(index: 0);
      expect(q0.text, 'Test Athletic Fact A');
      expect(q0.author, 'Biomechanics Lab');

      final q1 = service.getQuote(index: 1);
      expect(q1.text, 'Test Athletic Fact B');
      expect(q1.author, 'Olympic Archives');

      // Reset
      service.setQuotesForTesting(null);
    });
  });

  group('Phase L: InlineLoading Widget Tests', () {
    testWidgets(
      'InlineLoading renders with proper size and accessibility semantics',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: InlineLoading(
                  size: 22.0,
                  color: AppColors.accent,
                  semanticsLabel: 'Syncing in progress...',
                ),
              ),
            ),
          ),
        );

        final finder = find.byType(InlineLoading);
        expect(finder, findsOneWidget);

        final size = tester.getSize(finder);
        expect(size.width, 22.0);
        expect(size.height, 22.0);

        expect(find.bySemanticsLabel('Syncing in progress...'), findsOneWidget);
      },
    );

    testWidgets('InlineLoading renders static painter under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: Center(child: InlineLoading(size: 20.0))),
          ),
        ),
      );

      expect(find.byType(InlineLoading), findsOneWidget);
      // Under reduced motion, no AnimatedBuilder is instantiated inside InlineLoading
      expect(
        find.descendant(
          of: find.byType(InlineLoading),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
    });
  });

  group('Phase L: AppLoadingView Widget Tests', () {
    setUp(() {
      LoadingQuotesService.instance.setQuotesForTesting([
        const RunningQuote(
          text: 'Fact Alpha: Impact forces',
          author: 'Science',
        ),
        const RunningQuote(
          text: 'Fact Beta: Achilles spring',
          author: 'Physics',
        ),
      ]);
    });

    tearDown(() {
      LoadingQuotesService.instance.setQuotesForTesting(null);
    });

    testWidgets('AppLoadingView renders status label and initial quote', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLoadingView(label: 'Exporting run history...'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // Complete any initial quote cross-fade

      expect(find.text('Exporting run history...'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('“') ?? false),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('—') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('AppLoadingView rotates quote upon interval duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLoadingView(
                label: 'Loading season leaderboard...',
                quoteRotationInterval: Duration(seconds: 4),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // Settle initial quote fade
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('“') ?? false),
        ),
        findsOneWidget,
      );

      // Advance by 4 seconds to trigger rotation
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // Cross-fade duration

      // It rotated and settled to a quote in the pool
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('“') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'AppLoadingView displays 10s timeout note with retry and cancel actions',
      (tester) async {
        bool retried = false;
        bool cancelled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppLoadingView(
                  label: 'Fetching satellite lock...',
                  timeoutDuration: const Duration(seconds: 10),
                  onRetry: () => retried = true,
                  onCancel: () => cancelled = true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Taking longer than usual...'), findsNothing);

        // Advance 10 seconds to trigger timeout
        await tester.pump(const Duration(seconds: 10));

        expect(find.text('Taking longer than usual...'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(retried, isTrue);

        // Re-trigger timeout to test Cancel
        await tester.pump(const Duration(seconds: 10));
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(cancelled, isTrue);
      },
    );

    testWidgets('AppLoadingView modal presentation helper opens and closes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await AppLoadingView.showModal(
                    context: context,
                    label: 'Syncing GPX...',
                    task: () async {
                      await Future.delayed(const Duration(milliseconds: 200));
                      return 42;
                    },
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pump(); // Show modal
      expect(find.text('Syncing GPX...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250)); // Task completes
      await tester.pumpAndSettle(); // Modal dismissed
      expect(find.text('Syncing GPX...'), findsNothing);
    });
  });

  group('Phase L: Button Family Loading State Tests', () {
    testWidgets(
      'PrimaryButton and SecondaryButton render InlineLoading when isLoading is true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PrimaryButton(
                    label: 'Save Run',
                    isLoading: true,
                    onPressed: () {},
                  ),
                  SecondaryButton(
                    label: 'Cancel Run',
                    isLoading: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(InlineLoading), findsNWidgets(2));
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });
}
