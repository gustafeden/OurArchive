import 'dart:async';
import 'dart:collection';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/services/logger_service.dart';

enum TaskPriority { high, normal, low }

class SyncTask {
  final String id;
  final Future<void> Function() execute;
  final TaskPriority priority;
  final int maxRetries;
  int attempts = 0;
  DateTime? lastAttempt;
  String? lastError;

  SyncTask({
    required this.id,
    required this.execute,
    this.priority = TaskPriority.normal,
    this.maxRetries = 3,
  });
}

class SyncQueue {
  final Queue<SyncTask> _highPriority = Queue();
  final Queue<SyncTask> _normalPriority = Queue();
  final Queue<SyncTask> _lowPriority = Queue();

  bool _isProcessing = false;
  StreamSubscription? _connectivitySubscription;
  Timer? _retryTimer;
  final LoggerService _logger = LoggerService();

  SyncQueue() {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result.first != ConnectivityResult.none) {
        _logger.info('SyncQueue', 'Connectivity restored, processing queue');
        process();
      }
    });

    // Retry failed tasks every 30 seconds
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) => process());
  }

  void add(SyncTask task) {
    _logger.debug('SyncQueue', 'Adding task ${task.id} with priority ${task.priority.name}');

    switch (task.priority) {
      case TaskPriority.high:
        _highPriority.add(task);
        break;
      case TaskPriority.normal:
        _normalPriority.add(task);
        break;
      case TaskPriority.low:
        _lowPriority.add(task);
        break;
    }

    process();
  }

  Future<void> process() async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first == ConnectivityResult.none) {
        _logger.warn('SyncQueue', 'No connectivity, skipping queue processing');
        return;
      }

      _logger.debug('SyncQueue', 'Processing sync queues (H:${_highPriority.length}, N:${_normalPriority.length}, L:${_lowPriority.length})');

      // Process high priority first
      await _processQueue(_highPriority);
      await _processQueue(_normalPriority);
      await _processQueue(_lowPriority);

    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processQueue(Queue<SyncTask> queue) async {
    while (queue.isNotEmpty) {
      final task = queue.removeFirst();

      try {
        task.lastAttempt = DateTime.now();
        _logger.debug('SyncQueue', 'Executing task ${task.id} (attempt ${task.attempts + 1}/${task.maxRetries})');
        await task.execute();
        _logger.info('SyncQueue', 'Task ${task.id} completed successfully');
        // Success - task is done
      } catch (error, stackTrace) {
        task.attempts++;
        task.lastError = error.toString();

        if (task.attempts < task.maxRetries) {
          // Re-add to queue for retry
          _logger.warn('SyncQueue', 'Task ${task.id} failed (attempt ${task.attempts}/${task.maxRetries}), will retry', error);
          queue.add(task);
        } else {
          // Max retries reached - log error to both logger and Crashlytics
          _logger.error('SyncQueue', 'Task ${task.id} failed after ${task.maxRetries} attempts', error, stackTrace);
        }
      }
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }

  // Get queue stats for debug screen
  Map<String, int> getStats() => {
    'high': _highPriority.length,
    'normal': _normalPriority.length,
    'low': _lowPriority.length,
  };
}
