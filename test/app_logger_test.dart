import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/core/logging/app_logger.dart';

void main() {
  group('AppLogger Unit Tests', () {
    test('Logs at debug level without error', () {
      expect(
        () => AppLogger.debug('Test debug message', tag: 'UnitTest'),
        returnsNormally,
      );
    });

    test('Logs at info level without error', () {
      expect(
        () => AppLogger.info('Test info message', tag: 'UnitTest'),
        returnsNormally,
      );
    });

    test('Logs at warning level without error', () {
      expect(
        () => AppLogger.warning(
          'Test warning message',
          tag: 'UnitTest',
          error: Exception('Recoverable test warning'),
        ),
        returnsNormally,
      );
    });

    test('Logs at error level with stack trace without error', () {
      expect(
        () => AppLogger.error(
          'Test error message',
          tag: 'UnitTest',
          error: StateError('Unexpected test state'),
          stackTrace: StackTrace.current,
          fatal: false,
        ),
        returnsNormally,
      );
    });

    test('Crashlytics is strictly disabled in debug/test mode', () {
      AppLogger.setCrashlyticsEnabled(true);
      // In kDebugMode, setCrashlyticsEnabled safely forces _crashlyticsEnabled to false
      expect(AppLogger.isCrashlyticsEnabled, isFalse);
    });
  });
}
