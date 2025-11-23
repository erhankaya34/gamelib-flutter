import 'package:logger/logger.dart';

/// Shared logger wrapper to keep logging consistent across layers.
class AppLogger {
  AppLogger._()
      : _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 80,
            colors: false,
            printEmojis: false,
          ),
        );

  static final AppLogger instance = AppLogger._();

  final Logger _logger;

  void debug(String message) => _logger.d(message);
  void info(String message) => _logger.i(message);
  void warning(String message) => _logger.w(message);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}

/// Convenient top-level accessor for logging.
final AppLogger appLogger = AppLogger.instance;
