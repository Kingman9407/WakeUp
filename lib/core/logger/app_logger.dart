import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLoggerHelper {
  static final Logger _logger = Logger(
    level: kReleaseMode ? Level.off : Level.debug,

    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  /// Log info messages
  static void logInfo(String message) {
    _logger.i(message);
  }

  /// Log API or general response
  static void logResponse(dynamic response) {
    _logger.d("Response: $response");
  }

  /// Log error with optional stack trace
  static void logError(String error, [StackTrace? stackTrace]) {
    _logger.e("Error: $error", error: error, stackTrace: stackTrace);
  }

  /// Log warning
  static void logWarning(dynamic message) {
    _logger.w(message);
  }
}
