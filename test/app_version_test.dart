import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/theme/app_version.dart';

void main() {
  setUp(() {
    AppVersion.reset();
  });

  tearDown(() {
    AppVersion.reset();
  });

  group('AppVersion', () {
    test('defaults match fallback values', () {
      expect(AppVersion.version, equals('1.0.0'));
      expect(AppVersion.buildNumber, equals('1'));
      expect(AppVersion.full, equals('v1.0.0+1'));
      expect(AppVersion.display, equals('v1.0.0 (1)'));
    });

    test('mock updates version and buildNumber formatting', () {
      AppVersion.setMock(version: '2.1.0', buildNumber: '42');

      expect(AppVersion.version, equals('2.1.0'));
      expect(AppVersion.buildNumber, equals('42'));
      expect(AppVersion.full, equals('v2.1.0+42'));
      expect(AppVersion.display, equals('v2.1.0 (42)'));
    });

    test('reset restores default values', () {
      AppVersion.setMock(version: '9.9.9', buildNumber: '99');
      AppVersion.reset();

      expect(AppVersion.version, equals('1.0.0'));
      expect(AppVersion.buildNumber, equals('1'));
    });
  });
}
