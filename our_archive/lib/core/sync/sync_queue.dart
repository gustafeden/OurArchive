import 'dart:async';
import 'dart:collection';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  SyncQueue() {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result.first != ConnectivityResult.none) {
        process();
      }
    });

    // Retry failed tasks every 30 seconds
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) => process());
  }

  void add(SyncTask task) {
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
        return;
      }

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
        await task.execute();
        // Success - task is done
      } catch (error) {
        task.attempts++;
        task.lastError = error.toString();

        if (task.attempts < task.maxRetries) {
          // Re-add to queue for retry
          queue.add(task);
        } else {
          // Max retries reached - log error
          // In production, you might want to log to Crashlytics
          // ignore: avoid_print
          print('Task ${task.id} failed after ${task.maxRetries} attempts: $error');
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
