import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/item.dart';
import '../../providers/providers.dart';
import '../../utils/text_search_helper.dart';
import '../widgets/common/search_results_view.dart';
import '../widgets/scanner/item_preview_dialog.dart';
import '../widgets/scanner/camera_scanner_view.dart';
import '../widgets/scanner/manual_entry_view.dart';
import '../widgets/scanner/photo_ocr_view.dart';
import '../widgets/scanner/scan_mode_selector.dart';
import 'mixins/base_scanner_mixin.dart';
import 'mixins/duplicate_check_mixin.dart';
import 'mixins/post_scan_navigation_mixin.dart';
import 'mixins/ocr_mixin.dart';
import 'common/scan_modes.dart';
import 'add_book_screen.dart';

class BookScanScreen extends ConsumerStatefulWidget {
  final String householdId;
  final ScanMode initialMode;
  final String? preSelectedContainerId;

  const BookScanScreen({
    super.key,
    required this.householdId,
    this.initialMode = ScanMode.camera,
    this.preSelectedContainerId,
  });

  @override
  ConsumerState<BookScanScreen> createState() => _BookScanScreenState();
}

class _BookScanScreenState extends ConsumerState<BookScanScreen>
    with BaseScannerMixin, DuplicateCheckMixin, PostScanNavigationMixin, OcrMixin {

  late ScanMode _currentMode;
  String? _extractedText;

  @override
  String get householdId => widget.householdId;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    initializeScanner();
  }

  @override
  void dispose() {
    disposeScanner();
    disposeOcr();
    super.dispose();
  }

  // OCR photo capture and text extraction
  Future<void> _handlePhotoCapture() async {
    setState(() {
      isSearching = true;
      _extractedText = null;
      searchResults = [];
    });

    final extractedText = await captureAndRecognizeText();

    if (!mounted) return;

    setState(() {
      _extractedText = extractedText;
    });

    if (extractedText == null || extractedText.isEmpty) {
      setState(() => isSearching = false);
      return;
    }

    // Search for books using extracted text
    final bookLookupService = ref.read(bookLookupServiceProvider);
    final results = await bookLookupService.searchByText(extractedText);

    if (!mounted) return;

    setState(() {
      searchResults = results;
      isSearching = false;
    });

    if (results.isEmpty) {
      showError('No books found for: "$extractedText".\nTry manual search instead.');
    }
  }

  // Text search for books
  Future<void> _performTextSearch() async {
    final bookLookupService = ref.read(bookLookupServiceProvider);

    await TextSearchHelper.performSearchWithState<BookMetadata>(
      context: context,
      query: textSearchController.text,
      searchFunction: (query) => bookLookupService.searchByText(query),
      setState: setState,
      setIsSearching: (value) => isSearching = value,
      setSearchResults: (results) => searchResults = results,
      emptyMessage: 'No books found. Try a different search term.',
      itemTypeName: 'book title or author',
    );
  }

  // Handle tapping a search result
  Future<void> _handleSearchResultTap(BookMetadata book) async {
    BookMetadata? fullMetadata;

    if (book.isbn.isNotEmpty) {
      setState(() => isProcessing = true);

      try {
        final bookLookupService = ref.read(bookLookupServiceProvider);
        fullMetadata = await bookLookupService.lookupBook(book.isbn);
      } catch (e) {
        debugPrint('Failed to fetch full book metadata: $e');
      }

      if (!mounted) return;
      setState(() => isProcessing = false);
    }

    final bookToAdd = fullMetadata ?? book;

    // Check for duplicate
    final itemRepository = ref.read(itemRepositoryProvider);
    if (bookToAdd.isbn.isNotEmpty) {
      final existingItem = await itemRepository.findItemByIsbn(
        householdId,
        bookToAdd.isbn,
      );

      if (!mounted) return;

      if (existingItem != null) {
        final action = await handleDuplicateFlow(
          existingItem: existingItem,
          itemTypeName: 'Book',
        );

        if (action != 'addCopy') return;
      }
    }

    // Navigate to AddBookScreen
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBookScreen(
          householdId: householdId,
          bookData: bookToAdd,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
      ),
    );
  }

  // Handle barcode detection from camera
  Future<void> _handleBarcode(String code) async {
    if (!shouldProcessBarcode(code)) return;

    startProcessing(code);
    await _lookupBook(code);
  }

  // Handle manual ISBN entry
  Future<void> _handleManualEntry() async {
    final code = validateManualEntry();
    if (code == null) return;

    setState(() => isProcessing = true);
    await _lookupBook(code);
  }

  // Lookup book by ISBN
  Future<void> _lookupBook(String isbn) async {
    try {
      final bookLookupService = ref.read(bookLookupServiceProvider);
      final itemRepository = ref.read(itemRepositoryProvider);

      // Run book lookup and duplicate check in parallel
      final results = await Future.wait([
        bookLookupService.lookupBook(isbn),
        itemRepository.findItemByIsbn(householdId, isbn),
      ]);

      if (!mounted) return;

      final bookMetadata = results[0] as BookMetadata?;
      final existingItem = results[1] as Item?;

      if (bookMetadata == null) {
        showError('Book not found for ISBN: $isbn');
        resetScanning();
        return;
      }

      if (!mounted) return;

      String? action;

      // Check for duplicate
      if (existingItem != null) {
        action = await handleDuplicateFlow(
          existingItem: existingItem,
          itemTypeName: 'Book',
        );

        if (!mounted) return;

        if (action == 'addCopy') {
          action = await _showBookPreview(bookMetadata);
        } else {
          return; // User chose to scan next or cancelled
        }
      } else {
        action = await _showBookPreview(bookMetadata);
      }

      if (!mounted) return;

      await handlePostScanNavigation(
        action: action,
        addScreen: AddBookScreen(
          householdId: householdId,
          bookData: bookMetadata,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
        successMessage: 'Book added! Scan next book',
        itemLabel: 'Book',
      );
    } catch (e) {
      if (!mounted) return;
      showError('Error looking up book: $e');
      resetScanning();
    }
  }

  // Show book preview dialog
  Future<String?> _showBookPreview(BookMetadata book) async {
    return showItemPreviewDialog(
      context: context,
      title: 'Book Found',
      imageUrl: book.thumbnailUrl,
      fallbackIcon: Ionicons.book_outline,
      itemTitle: book.title ?? 'Unknown Title',
      creator: book.authors.isNotEmpty ? book.authors.join(', ') : null,
      metadataFields: [
        if (book.isbn.isNotEmpty) ItemPreviewField(label: 'ISBN', value: book.isbn),
      ],
      primaryActionLabel: 'Add Book',
    );
  }

  // Build the appropriate body based on current mode
  Widget _buildBody() {
    switch (_currentMode) {
      case ScanMode.camera:
        return CameraScannerView(
          controller: scannerController,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _handleBarcode(barcode.rawValue!);
                break;
              }
            }
          },
          isProcessing: isProcessing,
          itemsScanned: itemsScanned,
          instructionText: 'Position ISBN barcode in frame',
          scannedItemLabel: 'Books scanned',
          onSwitchToManualEntry: () {
            setState(() {
              _currentMode = ScanMode.manual;
            });
          },
        );

      case ScanMode.manual:
        return ManualEntryView(
          controller: manualIsbnController,
          labelText: 'ISBN',
          hintText: 'Enter ISBN or barcode',
          buttonText: 'Look Up Book',
          isProcessing: isProcessing,
          onSubmit: _handleManualEntry,
        );

      case ScanMode.textSearch:
        return SearchResultsView<BookMetadata>(
          controller: textSearchController,
          labelText: 'Search',
          hintText: 'Book title or author',
          isSearching: isSearching,
          searchResults: searchResults.cast<BookMetadata>(),
          onSearch: _performTextSearch,
          resultBuilder: (context, book) => ListTile(
            leading: book.thumbnailUrl != null && book.thumbnailUrl!.isNotEmpty
                ? Image.network(book.thumbnailUrl!, width: 40, fit: BoxFit.cover)
                : const Icon(Ionicons.book_outline),
            title: Text(book.title ?? 'Unknown Title'),
            subtitle: book.authors.isNotEmpty ? Text(book.authors.join(', ')) : null,
            onTap: () => _handleSearchResultTap(book),
          ),
        );

      case ScanMode.photoOcr:
        return PhotoOcrView<BookMetadata>(
          title: 'Photo Search',
          description: 'Take a photo of your book cover or spine. We\'ll extract the text and search for matching books.',
          isSearching: isSearching,
          extractedText: _extractedText,
          searchResults: searchResults.cast<BookMetadata>(),
          onCapturePhoto: _handlePhotoCapture,
          onResultTap: _handleSearchResultTap,
          resultBuilder: (context, book) => ListTile(
            leading: book.thumbnailUrl != null && book.thumbnailUrl!.isNotEmpty
                ? Image.network(book.thumbnailUrl!, width: 40, fit: BoxFit.cover)
                : const Icon(Ionicons.book_outline),
            title: Text(book.title ?? 'Unknown Title'),
            subtitle: book.authors.isNotEmpty ? Text(book.authors.join(', ')) : null,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentMode.getTitle(itemType: 'Books')),
        actions: [
          if (_currentMode == ScanMode.camera)
            IconButton(
              icon: Icon(scannerController.torchEnabled
                  ? Ionicons.flash_outline
                  : Ionicons.flash_off_outline),
              onPressed: () => scannerController.toggleTorch(),
              tooltip: 'Toggle Flashlight',
            ),
          ScanModeSelector(
            currentMode: _currentMode,
            availableModes: const [
              ScanMode.camera,
              ScanMode.photoOcr,
              ScanMode.textSearch,
              ScanMode.manual,
            ],
            onModeSelected: (mode) {
              setState(() {
                _currentMode = mode;
                searchResults = [];
                _extractedText = null;
                isProcessing = false; // Reset processing state when switching modes
              });
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
