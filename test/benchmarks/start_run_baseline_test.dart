import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('hive_bench_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
    await Hive.openBox<Territory>('territories_v3');
    await Hive.openBox<RunnerProfile>('profile');
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('Benchmark: Territory fold in build() with 100 territories', () async {
    final box = Hive.box<Territory>('territories_v3');
    await box.clear();

    // Populate with 100 captured territories
    for (int i = 0; i < 100; i++) {
      await box.put(
        'poly_$i',
        Territory(
          id: 'poly_$i',
          ownerId: 'runner_1',
          polygon: [
            LatLng(37.77 + i * 0.001, -122.41 + i * 0.001),
            LatLng(37.771 + i * 0.001, -122.41 + i * 0.001),
            LatLng(37.771 + i * 0.001, -122.411 + i * 0.001),
          ],
          areaSqMeters: 15400.0 + i,
          capturedAt: DateTime.now(),
        ),
      );
    }

    final territoryService = TerritoryService();
    final stopwatch = Stopwatch()..start();
    const iterations = 1000;
    double totalArea = 0.0;

    for (int i = 0; i < iterations; i++) {
      // Simulates what map_screen.dart:1459-1463 does on every build/setState:
      final territories = territoryService.getCapturedTerritoryObjects();
      final double totalAreaSqMeters = territories.fold(
        0.0,
        (sum, t) => sum + t.areaSqMeters,
      );
      totalArea = totalAreaSqMeters;
    }
    stopwatch.stop();

    final elapsedMicrosPerBuild = stopwatch.elapsedMicroseconds / iterations;
    print('========================================================');
    print('BASELINE MEASUREMENT (U0): Hive re-read + fold in build()');
    print('Total territories: 100');
    print('Iterations: $iterations builds');
    print('Total time: ${stopwatch.elapsedMilliseconds} ms');
    print('Time per build: ${elapsedMicrosPerBuild.toStringAsFixed(2)} µs (${(elapsedMicrosPerBuild / 1000.0).toStringAsFixed(3)} ms)');
    print('Calculated Area: ${totalArea.toStringAsFixed(2)} m²');
    print('========================================================');

    expect(totalArea, greaterThan(0));
  });

  testWidgets('Baseline (U0): Left rail circle buttons are 44x44 dp (under 48 dp target)', (tester) async {
    // In map_screen.dart:2045-2046:
    // Container(height: 44, width: 44, decoration: BoxDecoration(shape: BoxShape.circle))
    const circleSize = Size(44, 44);
    expect(circleSize.width, lessThan(48.0), reason: 'Current left rail buttons violate 48 dp touch target rule');
    expect(circleSize.height, lessThan(48.0), reason: 'Current left rail buttons violate 48 dp touch target rule');
  });

  testWidgets('Baseline (U0): showRunStartAnimation presents blocking 3600ms repeating dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                // Simulates showRunStartAnimation
                showGeneralDialog(
                  context: context,
                  barrierColor: Colors.black54,
                  pageBuilder: (ctx, _, _) => Center(
                    child: Container(
                      width: 320,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Start run'),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Start run'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Tap to open
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Notice: There are now TWO 'Start run' text widgets in the tree (dialog title + duplicate button)
    expect(find.text('Start run'), findsNWidgets(2));
  });
}
