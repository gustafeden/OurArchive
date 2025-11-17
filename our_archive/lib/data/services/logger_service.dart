import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum LogLevel {
  debug,
  info,
  warn,
  error,
}

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  static const String _logFileName = 'app_logs.txt';
  static const int _maxLogSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int _maxLogAgeDays = 7;

  File? _logFile;
  final _logController = StreamController<String>.broadcast();
  bool _initialized = false;

  /// Stream of log messages for real-time monitoring
  Stream<String> get logStream => _logController.stream;

  /// Initialize the logger
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_logFileName');

      // Create log file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }

      // Clean up old logs on startup
      await _cleanupOldLogs();

      _initialized = true;
      await _log(LogLevel.info, 'Logger', 'Logger service initialized');
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  /// Log a debug message (only in debug builds)
  Future<void> debug(String tag, String message, [Object? error, StackTrace? stackTrace]) async {
    if (kDebugMode) {
      await _log(LogLevel.debug, tag, message, error, stackTrace);
    }
  }

  /// Log an info message
  Future<void> info(String tag, String message) async {
    await _log(LogLevel.info, tag, message);
  }

  /// Log a warning message
  Future<void> warn(String tag, String message, [Object? error]) async {
    await _log(LogLevel.warn, tag, message, error);
  }

  /// Log an error message and send to Crashlytics
  Future<void> error(String tag, String message, [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.error, tag, message, error, stackTrace);

    // Send errors to Firebase Crashlytics
    try {
      if (error != null && stackTrace != null) {
        await FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
      } else if (error != null) {
        await FirebaseCrashlytics.instance.recordError(error, StackTrace.current, reason: message);
      }
    } catch (e) {
      // Prevent cascading errors from Crashlytics failures
      debugPrint('Failed to record error to Crashlytics: $e');
    }
  }

  /// Internal logging method
  Future<void> _log(
    LogLevel level,
    String tag,
    String message,
    [Object? error,
    StackTrace? stackTrace]
  ) async {
    if (!_initialized) {
      debugPrint('[NOT INITIALIZED] [$tag] $message');
      return;
    }

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final levelStr = level.name.toUpperCase().padRight(5);

    final logEntry = StringBuffer();
    logEntry.writeln('[$timestamp] [$levelStr] [$tag] $message');

    if (error != null) {
      logEntry.writeln('  Error: $error');
    }

    if (stackTrace != null) {
      logEntry.writeln('  Stack trace:');
      logEntry.writeln('  ${stackTrace.toString().split('\n').join('\n  ')}');
    }

    final logMessage = logEntry.toString();

    // Write to file
    try {
      await _logFile?.writeAsString(
        logMessage,
        mode: FileMode.append,
        flush: true,
      );

      // Check file size and rotate if needed
      await _rotateLogsIfNeeded();
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }

    // Broadcast to stream
    _logController.add(logMessage);

    // Also print to console in debug mode
    if (kDebugMode) {
      debugPrint(logMessage.trim());
    }
  }

  /// Rotate logs if file size exceeds limit
  Future<void> _rotateLogsIfNeeded() async {
    if (_logFile == null) return;

    try {
      final fileSize = await _logFile!.length();
      if (fileSize > _maxLogSizeBytes) {
        // Create backup with timestamp
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final backupPath = '${_logFile!.path}.$timestamp.backup';
        await _logFile!.copy(backupPath);

        // Clear current log file
        await _logFile!.writeAsString('');

        await info('Logger', 'Log file rotated (size: ${fileSize ~/ 1024}KB)');
      }
    } catch (e) {
      debugPrint('Failed to rotate logs: $e');
    }
  }

  /// Clean up old log files
  Future<void> _cleanupOldLogs() async {
    if (_logFile == null) return;

    try {
      final directory = _logFile!.parent;
      final files = directory.listSync();
      final now = DateTime.now();

      for (var file in files) {
        if (file is File && file.path.contains(_logFileName) && file.path.endsWith('.backup')) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;

          if (age > _maxLogAgeDays) {
            await file.delete();
            debugPrint('Deleted old log file: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup old logs: $e');
    }
  }

  /// Get the current log file path
  String? get logFilePath => _logFile?.path;

  /// Get the current log file
  File? get logFile => _logFile;

  /// Read all logs as a string
  Future<String> readLogs() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return 'No logs available';
    }

    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Failed to read logs: $e';
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString('');
      await info('Logger', 'Logs cleared');
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _logController.close();
  }
}
