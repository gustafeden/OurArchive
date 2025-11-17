import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Mixin providing common scanner state and barcode processing logic
/// for all scanner screens.
///
/// This mixin reduces code duplication by centralizing:
/// - Common state variables (scanner controller, processing flags, counters)
/// - Barcode duplicate prevention logic
/// - Scan state reset functionality
/// - Counter management
mixin BaseScannerMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  // Scanner controllers
  late MobileScannerController scannerController;
  final TextEditingController manualIsbnController = TextEditingController();
  final TextEditingController textSearchController = TextEditingController();

  // Processing state
  bool isProcessing = false;
  String? lastScannedCode;
  int itemsScanned = 0;

  // Search state (for text search modes)
  bool isSearching = false;
  List<dynamic> searchResults = [];

  /// Initialize the scanner controller
  /// Call this in initState() of the implementing widget
  void initializeScanner() {
    scannerController = MobileScannerController();
  }

  /// Dispose of all controllers
  /// Call this in dispose() of the implementing widget
  void disposeScanner() {
    scannerController.dispose();
    manualIsbnController.dispose();
    textSearchController.dispose();
  }

  /// Process a scanned barcode with duplicate prevention
  ///
  /// Returns true if the barcode should be processed, false if it's a duplicate
  bool shouldProcessBarcode(String code) {
    if (isProcessing || code == lastScannedCode) {
      return false;
    }
    return true;
  }

  /// Mark a barcode as being processed
  void startProcessing(String code) {
    setState(() {
      isProcessing = true;
      lastScannedCode = code;
    });
  }

  /// Reset the scanning state to allow new scans
  void resetScanning() {
    if (mounted) {
      setState(() {
        isProcessing = false;
        lastScannedCode = null;
      });
    }
  }

  /// Increment the scanned items counter
  void incrementCounter() {
    if (mounted) {
      setState(() => itemsScanned++);
    }
  }

  /// Handle manual entry with validation
  ///
  /// Returns the entered code if valid, null otherwise
  String? validateManualEntry() {
    final code = manualIsbnController.text.trim();

    if (code.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter an ISBN or barcode'),
          ),
        );
      }
      return null;
    }

    return code;
  }

  /// Show an error message to the user
  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show a success message to the user
  void showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
