import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/vinyl_metadata.dart';
import '../../data/models/item.dart';
import '../../providers/providers.dart';
import '../../services/vinyl_lookup_service.dart';
import '../widgets/common/item_found_dialog.dart';
import 'add_item_screen.dart';
import 'add_vinyl_screen.dart';

class ScanToCheckScreen extends ConsumerStatefulWidget {
  final String householdId;
  final String householdName;

  const ScanToCheckScreen({
    super.key,
    required this.householdId,
    required this.householdName,
  });

  @override
  ConsumerState<ScanToCheckScreen> createState() => _ScanToCheckScreenState();
}

class _ScanToCheckScreenState extends ConsumerState<ScanToCheckScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualIsbnController = TextEditingController();
  bool _isProcessing = false;
  bool _showManualEntry = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualIsbnController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String code) async {
    // Prevent duplicate scans
    if (_isProcessing || code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    // Detect barcode type - ISBN for books, UPC/EAN for vinyl
    if (_isIsbn(code)) {
      await _checkBook(code);
    } else {
      await _checkVinyl(code);
    }
  }

  bool _isIsbn(String code) {
    // Remove hyphens and spaces
    final cleaned = code.replaceAll(RegExp(r'[-\s]'), '');

    // ISBN-10 is 10 digits (possibly ending with X)
    // ISBN-13 is 13 digits and typically starts with 978 or 979
    if (cleaned.length == 10 && RegExp(r'^\d{9}[\dX]$').hasMatch(cleaned)) {
      return true;
    }
    if (cleaned.length == 13 && RegExp(r'^(978|979)\d{10}$').hasMatch(cleaned)) {
      return true;
    }

    return false;
  }

  Future<void> _handleManualEntry() async {
    final code = _manualIsbnController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an ISBN or barcode')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Detect barcode type - ISBN for books, UPC/EAN for vinyl
    if (_isIsbn(code)) {
      await _checkBook(code);
    } else {
      await _checkVinyl(code);
    }
  }

  Future<void> _checkBook(String isbn) async {
    try {
      final itemRepository = ref.read(itemRepositoryProvider);

      // Check if book exists in household
      final existingItem = await itemRepository.findItemByIsbn(widget.householdId, isbn);

      if (!mounted) return;

      if (existingItem != null) {
        // Book found in collection
        final action = await _showBookFoundDialog(existingItem);

        if (!mounted) return;

        if (action == 'scanNext') {
          // Reset for next scan
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
        } else {
          // Close scanner
          if (mounted) {
            Navigator.pop(context);
          }
        }
      } else {
        // Book not found - lookup metadata
        final bookLookupService = ref.read(bookLookupServiceProvider);
        final bookMetadata = await bookLookupService.lookupBook(isbn);

        if (!mounted) return;

        if (bookMetadata == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No book information found for ISBN: $isbn'),
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
          return;
        }

        // Show "not found" dialog with option to add
        final action = await _showBookNotFoundDialog(bookMetadata);

        if (!mounted) return;

        if (action == 'addBook') {
          // Navigate to AddItemScreen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemScreen(
                householdId: widget.householdId,
                bookData: bookMetadata,
              ),
            ),
          );

          if (mounted) {
            // Reset for next scan after adding
            setState(() {
              _isProcessing = false;
              _lastScannedCode = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Book added! Scan next book to check'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (action == 'scanNext') {
          // Reset for next scan without adding
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
        } else {
          // Close scanner
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking book: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  Future<void> _checkVinyl(String barcode) async {
    try {
      final itemRepository = ref.read(itemRepositoryProvider);

      // Run collection check and API lookup in parallel for better performance
      final results = await Future.wait([
        itemRepository.findItemByBarcode(widget.householdId, barcode),
        VinylLookupService.lookupByBarcode(barcode),
      ]);

      if (!mounted) return;

      var existingItem = results[0] as Item?;
      final vinylMetadata = results[1] as VinylMetadata?;

      // If not found by barcode but we have discogsId from API, try searching by discogsId
      // This handles old items that were stored with discogsId in barcode field
      if (existingItem == null && vinylMetadata?.discogsId != null) {
        existingItem = await itemRepository.findItemByDiscogsId(
          widget.householdId,
          vinylMetadata!.discogsId!,
        );
      }

      if (!mounted) return;

      if (existingItem != null) {
        // Vinyl found in collection
        final action = await _showVinylFoundDialog(existingItem);

        if (!mounted) return;

        if (action == 'scanNext') {
          // Reset for next scan
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
        } else {
          // Close scanner
          if (mounted) {
            Navigator.pop(context);
          }
        }
      } else if (vinylMetadata != null) {
        // Vinyl not found in collection but found in API
        // Show "not found" dialog with option to add
        final action = await _showVinylNotFoundDialog(vinylMetadata);

        if (!mounted) return;

        if (action == 'addVinyl') {
          // Navigate to AddVinylScreen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddVinylScreen(
                householdId: widget.householdId,
                vinylData: vinylMetadata,
              ),
            ),
          );

          if (mounted) {
            // Reset for next scan after adding
            setState(() {
              _isProcessing = false;
              _lastScannedCode = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Music added! Scan next item to check'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (action == 'scanNext') {
          // Reset for next scan without adding
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
        } else {
          // Close scanner
          if (mounted) {
            Navigator.pop(context);
          }
        }
      } else {
        // Neither found in collection nor in API
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No music information found for barcode: $barcode'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking music: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  Future<String?> _showBookFoundDialog(Item item) async {
    return showItemFoundDialog(
      context: context,
      ref: ref,
      item: item,
      householdId: widget.householdId,
      itemTypeName: 'Book',
      fallbackIcon: Icons.book,
      showAddCopyOption: false,
    );
  }

  Future<String?> _showBookNotFoundDialog(BookMetadata book) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Not in Your Collection'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book.thumbnailUrl != null)
                Center(
                  child: Image.network(
                    book.thumbnailUrl!,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.book, size: 100),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                book.title ?? 'Unknown Title',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (book.authors.isNotEmpty)
                Text(
                  'By ${book.authorsDisplay}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 8),
              if (book.publisher != null)
                Text('Publisher: ${book.publisher}'),
              if (book.publishedDate != null)
                Text('Published: ${book.publishedDate}'),
              if (book.pageCount != null) Text('Pages: ${book.pageCount}'),
              if (book.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  book.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'scanNext'),
            child: const Text('Scan Next'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'close'),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'addBook'),
            icon: const Icon(Icons.add),
            label: const Text('Add to Collection'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showVinylFoundDialog(Item item) async {
    return showItemFoundDialog(
      context: context,
      ref: ref,
      item: item,
      householdId: widget.householdId,
      itemTypeName: 'Music',
      fallbackIcon: Icons.album,
      showAddCopyOption: false,
    );
  }

  Future<String?> _showVinylNotFoundDialog(VinylMetadata vinyl) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Not in Your Collection'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vinyl.coverUrl != null && vinyl.coverUrl!.isNotEmpty)
                Center(
                  child: Image.network(
                    vinyl.coverUrl!,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.album, size: 100),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                vinyl.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (vinyl.artist.isNotEmpty)
                Text(
                  'By ${vinyl.artist}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 8),
              if (vinyl.label != null && vinyl.label!.isNotEmpty)
                Text('Label: ${vinyl.label}'),
              if (vinyl.year != null)
                Text('Year: ${vinyl.year}'),
              if (vinyl.format != null && vinyl.format!.isNotEmpty)
                Text('Format: ${vinyl.format!.join(', ')}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'scanNext'),
            child: const Text('Scan Next'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'close'),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'addVinyl'),
            icon: const Icon(Icons.add),
            label: const Text('Add to Collection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan to Check Items - ${widget.householdName}'),
        actions: [
          IconButton(
            icon: Icon(_scannerController.torchEnabled
                ? Icons.flash_on
                : Icons.flash_off),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: Icon(_showManualEntry ? Icons.qr_code_scanner : Icons.keyboard),
            onPressed: () {
              setState(() {
                _showManualEntry = !_showManualEntry;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_showManualEntry)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final code = barcode.rawValue;
                  if (code != null) {
                    _handleBarcode(code);
                    break;
                  }
                }
              },
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code, size: 100),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _manualIsbnController,
                      decoration: const InputDecoration(
                        labelText: 'Enter ISBN or Barcode',
                        hintText: '9780143127796 or UPC',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      onSubmitted: (_) => _handleManualEntry(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isProcessing ? null : _handleManualEntry,
                      icon: const Icon(Icons.search),
                      label: const Text('Check Item'),
                    ),
                  ],
                ),
              ),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Checking item...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
