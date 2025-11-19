import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A reusable camera scanner view with consistent UI across scanner screens.
///
/// Provides:
/// - Camera scanner with barcode detection
/// - Loading overlay during processing
/// - Bottom instruction banner with optional scan counter
/// - Consistent styling and layout
///
/// Usage:
/// ```dart
/// CameraScannerView(
///   controller: _scannerController,
///   onDetect: (capture) {
///     final barcodes = capture.barcodes;
///     for (final barcode in barcodes) {
///       if (barcode.rawValue != null) {
///         _handleBarcode(barcode.rawValue!);
///         break;
///       }
///     }
///   },
///   isProcessing: _isProcessing,
///   itemsScanned: _booksScanned,
///   instructionText: 'Position ISBN barcode in frame',
///   scannedItemLabel: 'Books scanned',
/// )
/// ```
class CameraScannerView extends StatelessWidget {
  /// Controller for the mobile scanner
  final MobileScannerController controller;

  /// Callback when barcode is detected
  final Function(BarcodeCapture) onDetect;

  /// Whether scanning is currently processing
  final bool isProcessing;

  /// Number of items scanned (optional, for counter display)
  final int itemsScanned;

  /// Instruction text to display at bottom
  final String instructionText;

  /// Label for scanned items counter (e.g., "Books scanned", "Music scanned")
  final String scannedItemLabel;

  const CameraScannerView({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.isProcessing,
    this.itemsScanned = 0,
    required this.instructionText,
    this.scannedItemLabel = 'Items scanned',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera scanner
        MobileScanner(
          controller: controller,
          onDetect: onDetect,
        ),

        // Processing overlay
        if (isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),

        // Bottom instruction banner
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black54,
            child: Text(
              itemsScanned > 0
                  ? '$scannedItemLabel: $itemsScanned\n$instructionText'
                  : instructionText,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
