import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/vinyl_metadata.dart';
import '../../data/models/household.dart';
import '../../data/models/item.dart';
import '../../data/models/container.dart' as model;
import '../../providers/providers.dart';
import '../../services/vinyl_lookup_service.dart';
import 'add_book_screen.dart';
import 'add_vinyl_screen.dart';

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

enum ScanMode { camera, manualIsbn, textSearch, photoSearch }

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualIsbnController = TextEditingController();
  final TextEditingController _textSearchController = TextEditingController();
  bool _isProcessing = false;
  ScanMode _currentMode = ScanMode.camera;
  String? _lastScannedCode;
  int _booksScanned = 0;
  List<BookMetadata> _searchResults = [];
  bool _isSearching = false;
  String? _extractedText;
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void dispose() {
    _scannerController.dispose();
    _manualIsbnController.dispose();
    _textSearchController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _captureAndRecognizeText() async {
    try {
      // Pick image from camera or gallery
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo == null) return;

      setState(() {
        _isSearching = true;
        _extractedText = null;
        _searchResults = [];
      });

      // Perform OCR on the image
      final inputImage = InputImage.fromFilePath(photo.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (!mounted) return;

      // Extract text
      final extractedText = recognizedText.text.trim();

      setState(() {
        _extractedText = extractedText;
      });

      if (extractedText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in image. Try again with better lighting.')),
          );
        }
        setState(() {
          _isSearching = false;
        });
        return;
      }

      // Use extracted text to search for books
      final bookLookupService = ref.read(bookLookupServiceProvider);
      final results = await bookLookupService.searchByText(extractedText);

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No books found for: "$extractedText".\nTry manual search instead.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recognizing text: ${e.toString()}')),
      );
    }
  }

  Future<void> _performTextSearch() async {
    final query = _textSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a book title or author')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final bookLookupService = ref.read(bookLookupServiceProvider);
      final results = await bookLookupService.searchByText(query);

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No books found. Try a different search term.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleSearchResultTap(BookMetadata book) async {
    // If the book has an ISBN, fetch full metadata
    BookMetadata? fullMetadata;
    if (book.isbn.isNotEmpty) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final bookLookupService = ref.read(bookLookupServiceProvider);
        fullMetadata = await bookLookupService.lookupBook(book.isbn);
      } catch (e) {
        debugPrint('Failed to fetch full book metadata: $e');
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });
    }

    // Use full metadata if available, otherwise use search result
    final bookToAdd = fullMetadata ?? book;

    // Check for duplicate
    final itemRepository = ref.read(itemRepositoryProvider);
    if (bookToAdd.isbn.isNotEmpty) {
      final existingItem = await itemRepository.findItemByIsbn(
        widget.household.id,
        bookToAdd.isbn,
      );

      if (!mounted) return;

      if (existingItem != null) {
        final action = await _showDuplicateFoundDialog(existingItem, bookToAdd);

        if (action == 'scanNext' || action == null) {
          setState(() {
            _isProcessing = false;
          });
          return;
        } else if (action == 'addCopy') {
          // Continue to add another copy
        }
      }
    }

    // Navigate to AddBookScreen
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBookScreen(
          household: widget.household,
          bookData: bookToAdd,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
      ),
    );
  }

  Future<void> _handleBarcode(String code) async {
    // Prevent duplicate scans
    if (_isProcessing || code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    // Try vinyl lookup first, then fall back to book lookup
    await _lookupItem(code);
  }

  Future<void> _handleManualEntry() async {
    final isbn = _manualIsbnController.text.trim();
    if (isbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an ISBN or barcode')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await _lookupItem(isbn);
  }

  Future<void> _lookupItem(String code) async {
    // Try vinyl lookup first (since vinyl barcodes are more specific)
    try {
      final vinylMetadata = await VinylLookupService.lookupByBarcode(code);

      if (!mounted) return;

      if (vinylMetadata != null) {
        await _handleVinylFound(code, vinylMetadata);
        return;
      }
    } catch (e) {
      // Vinyl lookup failed, continue to book lookup
    }

    // Fall back to book lookup
    await _lookupBook(code);
  }

  Future<void> _handleVinylFound(String barcode, VinylMetadata vinylMetadata) async {
    try {
      // Check if vinyl already exists in household
      final itemRepository = ref.read(itemRepositoryProvider);
      final existingItem = await itemRepository.findItemByBarcode(
        widget.household.id,
        barcode,
      );

      if (!mounted) return;

      String? action;

      if (existingItem != null) {
        action = await _showDuplicateFoundDialog(existingItem, null, vinylMetadata: vinylMetadata);

        if (!mounted) return;

        if (action == 'addCopy') {
          action = await _showVinylPreview(vinylMetadata);
        } else if (action == 'scanNext') {
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
          return;
        } else {
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
          return;
        }
      } else {
        action = await _showVinylPreview(vinylMetadata);
      }

      if (!mounted) return;

      if (action == 'addVinyl') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddVinylScreen(
              household: widget.household,
              vinylData: vinylMetadata,
              preSelectedContainerId: widget.preSelectedContainerId,
            ),
          ),
        );

        if (mounted) {
          Navigator.pop(context);
        }
      } else if (action == 'scanNext') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddVinylScreen(
              household: widget.household,
              vinylData: vinylMetadata,
              preSelectedContainerId: widget.preSelectedContainerId,
            ),
          ),
        );

        if (mounted) {
          setState(() {
            _booksScanned++;
            _isProcessing = false;
            _lastScannedCode = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vinyl added! Scan next item ($_booksScanned scanned)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing vinyl: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
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
        // Navigate to AddBookScreen to add this book, then close scanner
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddBookScreen(
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
        // Navigate to AddBookScreen but return to scanner
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddBookScreen(
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
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 100),
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
              if (book.publisher != null) Text('Publisher: ${book.publisher}'),
              if (book.publishedDate != null) Text('Published: ${book.publishedDate}'),
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
          FilledButton(
            onPressed: () => Navigator.pop(context, 'addBook'),
            child: const Text('Add Book'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showVinylPreview(VinylMetadata vinyl) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vinyl Record Found'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vinyl.coverUrl != null)
                Center(
                  child: Image.network(
                    vinyl.coverUrl!,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.album, size: 100),
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
              if (vinyl.label != null) Text('Label: ${vinyl.label}'),
              if (vinyl.year != null) Text('Year: ${vinyl.year}'),
              if (vinyl.catalogNumber != null) Text('Catalog #: ${vinyl.catalogNumber}'),
              if (vinyl.genre != null) Text('Genre: ${vinyl.genre}'),
              if (vinyl.format != null && vinyl.format!.isNotEmpty) Text('Format: ${vinyl.format!.join(', ')}'),
              if (vinyl.country != null) Text('Country: ${vinyl.country}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'scanNext'),
            child: const Text('Scan Next'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'addVinyl'),
            child: const Text('Add Vinyl'),
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
      final containers = await containerService.getAllContainers(widget.household.id).first;

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

  Future<String?> _showDuplicateFoundDialog(Item item, BookMetadata? bookMetadata,
      {VinylMetadata? vinylMetadata}) async {
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
                        Icon(item.type == 'vinyl' ? Icons.album : Icons.book, size: 100),
                  ),
                )
              else if (bookMetadata?.thumbnailUrl != null)
                Center(
                  child: Image.network(
                    bookMetadata!.thumbnailUrl!,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 100),
                  ),
                )
              else if (vinylMetadata?.coverUrl != null)
                Center(
                  child: Image.network(
                    vinylMetadata!.coverUrl!,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.album, size: 100),
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
        title: Text(_currentMode == ScanMode.camera
            ? 'Scan Barcode'
            : _currentMode == ScanMode.manualIsbn
                ? 'Enter ISBN'
                : _currentMode == ScanMode.textSearch
                    ? 'Search Books'
                    : 'Photo Search'),
        actions: [
          if (_currentMode == ScanMode.camera)
            IconButton(
              icon: Icon(_scannerController.torchEnabled ? Icons.flash_on : Icons.flash_off),
              onPressed: () => _scannerController.toggleTorch(),
              tooltip: 'Toggle Flashlight',
            ),
          PopupMenuButton<ScanMode>(
            icon: Icon(_currentMode == ScanMode.camera
                ? Icons.qr_code_scanner
                : _currentMode == ScanMode.manualIsbn
                    ? Icons.keyboard
                    : _currentMode == ScanMode.textSearch
                        ? Icons.search
                        : Icons.photo_camera),
            tooltip: 'Switch Mode',
            onSelected: (mode) {
              setState(() {
                _currentMode = mode;
                _searchResults = [];
                _extractedText = null;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ScanMode.camera,
                child: ListTile(
                  leading: Icon(Icons.qr_code_scanner),
                  title: Text('Scan Barcode'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: ScanMode.manualIsbn,
                child: ListTile(
                  leading: Icon(Icons.keyboard),
                  title: Text('Enter ISBN'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: ScanMode.textSearch,
                child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text('Search by Title/Author'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: ScanMode.photoSearch,
                child: ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('Photo Search (OCR)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_currentMode == ScanMode.camera)
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
          else if (_currentMode == ScanMode.manualIsbn)
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
            )
          else if (_currentMode == ScanMode.textSearch)
            // Text Search Mode
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _textSearchController,
                        decoration: const InputDecoration(
                          labelText: 'Book Title or Author',
                          hintText: 'e.g., "1984 Orwell" or "Harry Potter"',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        autofocus: true,
                        onSubmitted: (_) => _performTextSearch(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSearching ? null : _performTextSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Search Books'),
                      ),
                    ],
                  ),
                ),
                if (_isSearching)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_searchResults.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 80,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Enter a book title or author to search',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final book = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: book.thumbnailUrl != null
                                ? Image.network(
                                    book.thumbnailUrl!,
                                    width: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.book),
                                  )
                                : const Icon(Icons.book),
                            title: Text(book.title ?? 'Unknown Title'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (book.authors.isNotEmpty)
                                  Text(book.authors.join(', ')),
                                if (book.publishedDate != null)
                                  Text(book.publishedDate!,
                                      style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () => _handleSearchResultTap(book),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            )
          else
            // Photo Search Mode (OCR)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_camera,
                        size: 100,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Photo Search',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a photo of a book cover or spine.\nWe\'ll extract text and search for matches.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSearching ? null : _captureAndRecognizeText,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Take Photo'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                      if (_extractedText != null) ...[
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.text_fields,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Extracted Text:',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _extractedText!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isSearching)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Recognizing text and searching...'),
                        ],
                      ),
                    ),
                  )
                else if (_searchResults.isEmpty && _extractedText != null)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No books found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try taking another photo or use text search',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final book = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: book.thumbnailUrl != null
                                ? Image.network(
                                    book.thumbnailUrl!,
                                    width: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.book),
                                  )
                                : const Icon(Icons.book),
                            title: Text(book.title ?? 'Unknown Title'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (book.authors.isNotEmpty)
                                  Text(book.authors.join(', ')),
                                if (book.publishedDate != null)
                                  Text(book.publishedDate!,
                                      style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () => _handleSearchResultTap(book),
                          ),
                        );
                      },
                    ),
                  ),
              ],
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
