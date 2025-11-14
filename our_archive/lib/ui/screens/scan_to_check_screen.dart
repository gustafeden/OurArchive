import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/item.dart';
import '../../data/models/container.dart' as model;
import '../../providers/providers.dart';
import 'add_item_screen.dart';

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

    await _checkBook(code);
  }

  Future<void> _handleManualEntry() async {
    final isbn = _manualIsbnController.text.trim();
    if (isbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an ISBN')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await _checkBook(isbn);
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

  Future<String?> _showBookFoundDialog(Item item) async {
    // Get container name if item has one
    String locationText = 'Not assigned to a container';
    if (item.containerId != null) {
      try {
        // Temporarily set current household to get containers
        final previousHouseholdId = ref.read(currentHouseholdIdProvider);
        ref.read(currentHouseholdIdProvider.notifier).state = widget.householdId;

        final containerService = ref.read(containerServiceProvider);
        final containers = await containerService.getAllContainers(widget.householdId).first;

        // Restore previous household
        ref.read(currentHouseholdIdProvider.notifier).state = previousHouseholdId;

        final container = containers.firstWhere(
          (c) => c.id == item.containerId,
          orElse: () => model.Container(
            id: '',
            name: 'Unknown',
            householdId: widget.householdId,
            containerType: 'unknown',
            createdAt: DateTime.now(),
            lastModified: DateTime.now(),
            createdBy: '',
          ),
        );

        if (container.id.isNotEmpty) {
          locationText = 'In: ${container.name}';
        }
      } catch (e) {
        locationText = 'Location unavailable';
      }
    }

    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text('You Already Have This!'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.coverUrl != null)
                Center(
                  child: Image.network(
                    item.coverUrl!,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.book, size: 100),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (item.authors != null && item.authors!.isNotEmpty)
                Text(
                  'By ${item.authors!.join(", ")}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationText,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.quantity > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Quantity: ${item.quantity}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'close'),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'scanNext'),
            child: const Text('Scan Next'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan to Check - ${widget.householdName}'),
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
                    const Icon(Icons.book, size: 100),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _manualIsbnController,
                      decoration: const InputDecoration(
                        labelText: 'Enter ISBN',
                        hintText: '9780143127796',
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
                      label: const Text('Check Book'),
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
                        Text('Checking book...'),
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
