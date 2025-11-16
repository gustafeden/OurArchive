import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/item.dart';
import '../../providers/providers.dart';
import 'add_book_screen.dart';

enum BookScanMode { camera, manualIsbn, textSearch, photoOcr }

class BookScanScreen extends ConsumerStatefulWidget {
  final String householdId;
  final BookScanMode initialMode;
  final String? preSelectedContainerId;

  const BookScanScreen({
    super.key,
    required this.householdId,
    this.initialMode = BookScanMode.camera,
    this.preSelectedContainerId,
  });

  @override
  ConsumerState<BookScanScreen> createState() => _BookScanScreenState();
}

class _BookScanScreenState extends ConsumerState<BookScanScreen> {
  late MobileScannerController _scannerController;
  final TextEditingController _manualIsbnController = TextEditingController();
  final TextEditingController _textSearchController = TextEditingController();
  late BookScanMode _currentMode;
  bool _isProcessing = false;
  String? _lastScannedCode;
  int _booksScanned = 0;
  List<BookMetadata> _searchResults = [];
  bool _isSearching = false;
  String? _extractedText;
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _scannerController = MobileScannerController();
  }

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

      final inputImage = InputImage.fromFilePath(photo.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (!mounted) return;

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

    final bookToAdd = fullMetadata ?? book;

    // Check for duplicate
    final itemRepository = ref.read(itemRepositoryProvider);
    if (bookToAdd.isbn.isNotEmpty) {
      final existingItem = await itemRepository.findItemByIsbn(
        widget.householdId,
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
          householdId: widget.householdId,
          bookData: bookToAdd,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
      ),
    );
  }

  Future<void> _handleBarcode(String code) async {
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
          SnackBar(content: Text('Book not found for ISBN: $isbn')),
        );
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
        return;
      }

      // Check for duplicate
      final itemRepository = ref.read(itemRepositoryProvider);
      final existingItem = await itemRepository.findItemByIsbn(
        widget.householdId,
        isbn,
      );

      if (!mounted) return;

      if (existingItem != null) {
        final action = await _showDuplicateFoundDialog(existingItem, bookMetadata);

        if (action == 'scanNext' || action == null) {
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
          return;
        } else if (action == 'addCopy') {
          // Continue to add another copy
        }
      }

      // Show preview dialog
      final action = await _showBookPreview(bookMetadata);

      if (!mounted) return;

      if (action == 'addBook') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddBookScreen(
              householdId: widget.householdId,
              bookData: bookMetadata,
              preSelectedContainerId: widget.preSelectedContainerId,
            ),
          ),
        );
        // No need to pop - AddBookScreen handles navigation with popUntil
      } else if (action == 'scanNext') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddBookScreen(
              householdId: widget.householdId,
              bookData: bookMetadata,
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
              content: Text('Book added! Scan next book ($_booksScanned scanned)'),
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
        SnackBar(content: Text('Error looking up book: $e')),
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
              if (book.thumbnailUrl != null && book.thumbnailUrl!.isNotEmpty)
                Center(
                  child: Image.network(
                    book.thumbnailUrl!,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 100),
                  ),
                ),
              const SizedBox(height: 16),
              Text(book.title ?? 'Unknown Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (book.authors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('by ${book.authors.join(", ")}'),
              ],
              if (book.isbn.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('ISBN: ${book.isbn}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
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

  Future<String?> _showDuplicateFoundDialog(Item existingItem, BookMetadata book) async {
    String? containerName;

    if (existingItem.containerId != null) {
      try {
        final containerService = ref.read(containerServiceProvider);
        final containers = await containerService.getAllContainers(widget.householdId).first;
        final container = containers.firstWhere(
          (c) => c.id == existingItem.containerId,
          orElse: () => throw Exception('Container not found'),
        );
        containerName = container.name;
      } catch (e) {
        debugPrint('Error getting container name: $e');
      }
    }

    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book Already Exists'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This book is already in your collection:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(existingItem.title),
            if (containerName != null) ...[
              const SizedBox(height: 4),
              Text('Location: $containerName'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'scanNext'),
            child: const Text('Scan Next'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'addCopy'),
            child: const Text('Add Another Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Book'),
        actions: [
          PopupMenuButton<BookScanMode>(
            icon: const Icon(Icons.more_vert),
            onSelected: (mode) {
              setState(() {
                _currentMode = mode;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: BookScanMode.camera,
                child: ListTile(
                  leading: Icon(Icons.qr_code_scanner),
                  title: Text('Camera Scan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: BookScanMode.photoOcr,
                child: ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('Photo Search'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: BookScanMode.textSearch,
                child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text('Text Search'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: BookScanMode.manualIsbn,
                child: ListTile(
                  leading: Icon(Icons.keyboard),
                  title: Text('Manual ISBN'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentMode) {
      case BookScanMode.camera:
        return _buildCameraScanner();
      case BookScanMode.manualIsbn:
        return _buildManualIsbnEntry();
      case BookScanMode.textSearch:
        return _buildTextSearch();
      case BookScanMode.photoOcr:
        return _buildPhotoOcrSearch();
    }
  }

  Widget _buildCameraScanner() {
    return Stack(
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
            child: Text(
              _booksScanned > 0
                  ? 'Books scanned: $_booksScanned\nPosition ISBN barcode in frame'
                  : 'Position ISBN barcode in frame',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualIsbnEntry() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _manualIsbnController,
            decoration: const InputDecoration(
              labelText: 'ISBN',
              hintText: 'Enter ISBN or barcode',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _handleManualEntry(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isProcessing ? null : _handleManualEntry,
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Look Up Book'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    hintText: 'Book title or author',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _performTextSearch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSearching ? null : _performTextSearch,
                child: const Icon(Icons.search),
              ),
            ],
          ),
        ),
        if (_isSearching)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final book = _searchResults[index];
                return ListTile(
                  leading: book.thumbnailUrl != null && book.thumbnailUrl!.isNotEmpty
                      ? Image.network(book.thumbnailUrl!, width: 40, fit: BoxFit.cover)
                      : const Icon(Icons.book),
                  title: Text(book.title ?? 'Unknown Title'),
                  subtitle: book.authors.isNotEmpty ? Text(book.authors.join(', ')) : null,
                  onTap: () => _handleSearchResultTap(book),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoOcrSearch() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Photo Search',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take a photo of your book cover or spine. We\'ll extract the text and search for matching books.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSearching ? null : _captureAndRecognizeText,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Take Photo'),
          ),
          if (_extractedText != null) ...[
            const SizedBox(height: 16),
            const Text('Extracted text:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_extractedText!, style: const TextStyle(fontSize: 12)),
          ],
          if (_isSearching)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final book = _searchResults[index];
                  return ListTile(
                    leading: book.thumbnailUrl != null && book.thumbnailUrl!.isNotEmpty
                        ? Image.network(book.thumbnailUrl!, width: 40, fit: BoxFit.cover)
                        : const Icon(Icons.book),
                    title: Text(book.title ?? 'Unknown Title'),
                    subtitle: book.authors.isNotEmpty ? Text(book.authors.join(', ')) : null,
                    onTap: () => _handleSearchResultTap(book),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
