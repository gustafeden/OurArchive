import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

/// Standardized scan modes across all scanner screens
///
/// This enum provides a consistent set of scanning modes that can be
/// used by different scanner screens (books, vinyl, games, etc.).
/// Not all screens need to support all modes.
enum ScanMode {
  /// Camera barcode/QR code scanning
  camera,

  /// Manual ISBN/barcode entry via keyboard
  manual,

  /// Text-based search (title, author, etc.)
  textSearch,

  /// Photo OCR-based search
  photoOcr,
}

/// Extension providing UI-related properties for scan modes
extension ScanModeExtension on ScanMode {
  /// Display label for the scan mode
  String get label {
    switch (this) {
      case ScanMode.camera:
        return 'Scan Barcode';
      case ScanMode.manual:
        return 'Manual Entry';
      case ScanMode.textSearch:
        return 'Text Search';
      case ScanMode.photoOcr:
        return 'Photo Search (OCR)';
    }
  }

  /// Icon representing the scan mode
  IconData get icon {
    switch (this) {
      case ScanMode.camera:
        return Ionicons.qr_code_outline;
      case ScanMode.manual:
        return Ionicons.keypad_outline;
      case ScanMode.textSearch:
        return Ionicons.search_outline;
      case ScanMode.photoOcr:
        return Ionicons.camera_outline;
    }
  }

  /// AppBar title for the scan mode
  String getTitle({String itemType = 'Item'}) {
    switch (this) {
      case ScanMode.camera:
        return 'Scan Barcode';
      case ScanMode.manual:
        return 'Enter Code';
      case ScanMode.textSearch:
        return 'Search $itemType';
      case ScanMode.photoOcr:
        return 'Photo Search';
    }
  }

  /// Description text for the scan mode
  String getDescription({String itemType = 'item'}) {
    switch (this) {
      case ScanMode.camera:
        return 'Position barcode in frame to scan';
      case ScanMode.manual:
        return 'Enter ISBN or barcode manually';
      case ScanMode.textSearch:
        return 'Search by $itemType title or creator';
      case ScanMode.photoOcr:
        return 'Take a photo to extract and search text';
    }
  }
}
