import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_scanner_mixin.dart';

/// Mixin providing standardized navigation handling after item scanning
/// for scanner screens.
///
/// This mixin reduces code duplication by centralizing:
/// - Post-scan navigation logic (add vs scanNext)
/// - Counter increment and state reset
/// - Success message display
/// - Scanner screen closure handling
///
/// Must be used in conjunction with BaseScannerMixin
mixin PostScanNavigationMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, BaseScannerMixin<T> {
  // This mixin enforces compile-time dependency on BaseScannerMixin

  /// Handle navigation after item preview based on user action
  ///
  /// Supports two navigation patterns:
  /// - 'add': Navigate to add screen, then close scanner
  /// - 'scanNext': Navigate to add screen, return to scanner for next scan
  ///
  /// Parameters:
  /// - [action]: The action chosen by user ('add', 'scanNext', or null)
  /// - [addScreen]: The widget to navigate to for adding the item
  /// - [successMessage]: Message to show when returning to scanner
  /// - [itemLabel]: Label for item type (e.g., 'Book', 'Vinyl')
  Future<void> handlePostScanNavigation({
    required String? action,
    required Widget addScreen,
    required String successMessage,
    String itemLabel = 'Item',
  }) async {
    if (action == 'add') {
      // Navigate to add screen - the add screen handles popUntil to close all intermediate screens
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => addScreen),
      );
      // Don't pop here - AddScreen already does popUntil to return to container/list
    } else if (action == 'scanNext') {
      // Navigate to add screen, then return to scanner
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => addScreen),
      );

      if (mounted) {
        // Increment counter and reset for next scan
        incrementCounter();
        resetScanning();

        // Show success message with counter
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successMessage ($itemsScanned scanned)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // User cancelled - reset for next scan
      resetScanning();
    }
  }

  /// Simplified navigation for "scan to check" mode
  /// Just shows a message and resets without navigating
  void handleScanToCheckResult({
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;

    resetScanning();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }
}
