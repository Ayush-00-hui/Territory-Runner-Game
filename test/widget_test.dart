import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:territory_runner/main.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_widget_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
    await Hive.openBox<Territory>('territories_v3');
    await Hive.openBox<RunnerProfile>('profile');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('TerritoryApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TerritoryApp());
    expect(find.byType(TerritoryApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

