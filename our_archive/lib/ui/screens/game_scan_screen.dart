import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Placeholder screen for game barcode scanning
/// This can be enhanced in the future with game metadata lookup services
class GameScanScreen extends ConsumerStatefulWidget {
  final String householdId;
  final String? preSelectedContainerId;

  const GameScanScreen({
    super.key,
    required this.householdId,
    this.preSelectedContainerId,
  });

  @override
  ConsumerState<GameScanScreen> createState() => _GameScanScreenState();
}

class _GameScanScreenState extends ConsumerState<GameScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String code) async {
    if (_isProcessing || code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    // For now, just show the scanned barcode
    // In the future, this could lookup game metadata from IGDB or similar services
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scanned barcode: $code\nGame lookup not yet implemented'),
        duration: const Duration(seconds: 3),
      ),
    );

    setState(() {
      _isProcessing = false;
      _lastScannedCode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Game'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleBarcode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'Position game barcode in frame\n\nNote: Game metadata lookup will be added in a future update',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
