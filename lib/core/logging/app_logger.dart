import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Severity levels for application logging.
enum LogLevel { debug, info, warning, error }

/// A lightweight, unified application logger for Territory Runner.
///
/// Features:
/// - Silent in release mode for [LogLevel.debug] and [LogLevel.info].
/// - Emits [LogLevel.warning] and [LogLevel.error] across all environments.
/// - Forwards warnings and non-fatal/fatal errors to [FirebaseCrashlytics]
///   when initialized and active (strictly disabled in debug mode).
class AppLogger {
  AppLogger._();

  static bool _crashlyticsEnabled = false;

  /// Enables or disables Crashlytics telemetry.
  /// Strictly no-ops if in [kDebugMode] or if Crashlytics is uninitialized.
  static void setCrashlyticsEnabled(bool enabled) {
    if (kDebugMode) {
      _crashlyticsEnabled = false;
      return;
    }
    _crashlyticsEnabled = enabled;
    try {
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    } catch (_) {
      _crashlyticsEnabled = false;
    }
  }

  /// Whether Crashlytics error reporting is currently active.
  static bool get isCrashlyticsEnabled => _crashlyticsEnabled;

  /// Logs verbose diagnostic messages. Silent in release builds.
  static void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.debug,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs general operational information. Silent in release builds.
  static void info(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.info,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs unusual conditions or transient recoverable failures.
  static void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.warning,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs unexpected errors or caught exceptions.
  /// Automatically forwarded to Crashlytics in production when configured.
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fatal: fatal,
    );
  }

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    // In release builds, completely drop debug and info logs
    if (kReleaseMode && (level == LogLevel.debug || level == LogLevel.info)) {
      return;
    }

    final tagPrefix = tag != null ? '[$tag] ' : '';
    final levelName = level.name.toUpperCase();
    final formattedMessage = '[$levelName] $tagPrefix$message';

    if (kDebugMode) {
      debugPrint(formattedMessage);
      if (error != null) {
        debugPrint('  Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('  StackTrace: $stackTrace');
      }
    } else {
      // In release builds: print warnings and errors to system logcat/console
      // ignore: avoid_print
      print(formattedMessage);
      if (error != null) {
        // ignore: avoid_print
        print('  Error: $error');
      }
    }

    // Forward to Crashlytics in production
    if (_crashlyticsEnabled) {
      try {
        if (level == LogLevel.error) {
          FirebaseCrashlytics.instance.recordError(
            error ?? message,
            stackTrace ?? StackTrace.current,
            reason: message,
            fatal: fatal,
          );
        } else if (level == LogLevel.warning) {
          FirebaseCrashlytics.instance.log('[WARN] $tagPrefix$message');
        }
      } catch (_) {
        // Do not crash the app if Crashlytics dispatch fails
      }
    }
  }
}
