import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/household.dart';
import '../../data/models/item.dart';
import '../../data/models/container.dart' as model;
import '../../providers/providers.dart';
import 'add_item_screen.dart';

class BarcodeScanScreen extends ConsumerStatefulWidget {
  final Household household;
  final String? preSelectedContainerId;

  const BarcodeScanScreen({
    super.key,
    required this.household,
    this.preSelectedContainerId,
  });

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualIsbnController = TextEditingController();
  bool _isProcessing = false;
  bool _showManualEntry = false;
  String? _lastScannedCode;
  int _booksScanned = 0;

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

    await _lookupBook(code);
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

    await _lookupBook(isbn);
  }

  Future<void> _lookupBook(String isbn) async {
    try {
      final bookLookupService = ref.read(bookLookupServiceProvider);
      final bookMetadata = await bookLookupService.lookupBook(isbn);

      if (!mounted) return;

      if (bookMetadata == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No book found for ISBN: $isbn'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
        return;
      }

      // Check if book already exists in household
      final itemRepository = ref.read(itemRepositoryProvider);
      final existingItem = await itemRepository.findItemByIsbn(
        widget.household.id,
        isbn,
      );

      if (!mounted) return;

      String? action;

      // If book exists, show duplicate dialog first
      if (existingItem != null) {
        action = await _showDuplicateFoundDialog(existingItem, bookMetadata);

        if (!mounted) return;

        if (action == 'addCopy') {
          // User wants to add another copy - continue to book preview
          action = await _showBookPreview(bookMetadata);
        } else if (action == 'scanNext') {
          // Reset for next scan
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
          return;
        } else {
          // User cancelled - reset for next scan
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
          return;
        }
      } else {
        // Book not found - show normal preview dialog
        action = await _showBookPreview(bookMetadata);
      }

      if (!mounted) return;

      if (action == 'addBook') {
        // Navigate to AddItemScreen to add this book, then close scanner
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddItemScreen(
              household: widget.household,
              bookData: bookMetadata,
              preSelectedContainerId: widget.preSelectedContainerId,
            ),
          ),
        );

        if (mounted) {
          // Close scanner after adding book
          Navigator.pop(context);
        }
      } else if (action == 'scanNext') {
        // Navigate to AddItemScreen but return to scanner
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddItemScreen(
              household: widget.household,
              bookData: bookMetadata,
              preSelectedContainerId: widget.preSelectedContainerId,
            ),
          ),
        );

        if (mounted) {
          // Increment counter and reset for next scan
          setState(() {
            _booksScanned++;
            _isProcessing = false;
            _lastScannedCode = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Book added! Scan next book ($_booksScanned scanned)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // User cancelled - reset for next scan
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error looking up book: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  Future<String?> _showBookPreview(BookMetadata book) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book Found'),
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
              if (book.pageCount != null)
                Text('Pages: ${book.pageCount}'),
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
          FilledButton(
            onPressed: () => Navigator.pop(context, 'addBook'),
            child: const Text('Add Book'),
          ),
        ],
      ),
    );
  }

  Future<String> _getContainerName(String? containerId) async {
    if (containerId == null) {
      return 'Not assigned to a container';
    }

    try {
      final containerService = ref.read(containerServiceProvider);
      final containers = await containerService
          .getAllContainers(widget.household.id)
          .first;

      final container = containers.firstWhere(
        (c) => c.id == containerId,
        orElse: () => model.Container(
          id: '',
          name: 'Unknown',
          householdId: widget.household.id,
          containerType: 'unknown',
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
          createdBy: '',
        ),
      );

      return container.id.isNotEmpty ? 'In: ${container.name}' : 'Location unavailable';
    } catch (e) {
      return 'Location unavailable';
    }
  }

  Future<String?> _showDuplicateFoundDialog(Item item, BookMetadata bookMetadata) async {
    final locationText = await _getContainerName(item.containerId);

    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 28),
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
                )
              else if (bookMetadata.thumbnailUrl != null)
                Center(
                  child: Image.network(
                    bookMetadata.thumbnailUrl!,
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
              const SizedBox(height: 16),
              Text(
                'What would you like to do?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'scanNext'),
            child: const Text('Scan Next'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'addCopy'),
            icon: const Icon(Icons.add),
            label: const Text('Add Another Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Book Barcode'),
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
                      label: const Text('Look Up Book'),
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
                        Text('Looking up book...'),
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
