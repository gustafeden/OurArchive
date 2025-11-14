import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reusable AsyncValue widget to eliminate hundreds of .when() blocks
///
/// Instead of:
/// ```dart
/// containersAsync.when(
///   data: (containers) => DropdownList(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('Error: $e'),
/// )
/// ```
///
/// Use:
/// ```dart
/// AppAsyncValue(
///   value: containersAsync,
///   data: (containers) => DropdownList(...),
/// )
/// ```
class AppAsyncValue<T> extends StatelessWidget {
  const AppAsyncValue({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(T) data;
  final Widget Function()? loading;
  final Widget Function(Object, StackTrace)? error;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: loading ?? () => const Center(child: CircularProgressIndicator()),
      error: error ??
          (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

/// Slim variant for linear progress indicators (like in dropdowns)
class AppAsyncValueSlim<T> extends StatelessWidget {
  const AppAsyncValueSlim({
    super.key,
    required this.value,
    required this.data,
    this.errorMessage = 'Failed to load',
  });

  final AsyncValue<T> value;
  final Widget Function(T) data;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const LinearProgressIndicator(),
      error: (err, _) => Text(
        errorMessage,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}
