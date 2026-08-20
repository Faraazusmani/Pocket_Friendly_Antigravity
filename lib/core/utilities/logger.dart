import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as pkg;

abstract class AppLogger {
  void debug(String message, [dynamic error, StackTrace? stackTrace]);
  void info(String message, [dynamic error, StackTrace? stackTrace]);
  void warning(String message, [dynamic error, StackTrace? stackTrace]);
  void error(String message, [dynamic error, StackTrace? stackTrace]);
}

class AppLoggerImpl implements AppLogger {
  final pkg.Logger _logger;

  AppLoggerImpl({pkg.Logger? logger})
    : _logger =
          logger ??
          pkg.Logger(
            printer: pkg.PrettyPrinter(
              methodCount: 2,
              errorMethodCount: 8,
              lineLength: 120,
              colors: true,
              printEmojis: true,
            ),
            // Suppress output in release mode to satisfy security/privacy guidelines.
            filter: pkg.ProductionFilter(),
            output: _SanitizedConsoleOutput(),
          );

  @override
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  @override
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}

/// A custom console output that prevents logging output in release builds,
/// keeping local logging strictly private.
class _SanitizedConsoleOutput extends pkg.LogOutput {
  @override
  void output(pkg.OutputEvent event) {
    if (kDebugMode) {
      for (var line in event.lines) {
        // print is safe for development console view only
        // ignore: avoid_print
        print(line);
      }
    }
  }
}
