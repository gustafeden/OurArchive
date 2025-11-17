import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/vinyl_metadata.dart';
import '../../data/models/household.dart';
import '../../data/models/item.dart';
import '../../providers/providers.dart';
import '../../services/vinyl_lookup_service.dart';
import 'add_book_screen.dart';
import 'add_vinyl_screen.dart';
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

class BarcodeScanScreen extends ConsumerStatefulWidget {
  final String householdId;
  final String? preSelectedContainerId;

  const BarcodeScanScreen({
    super.key,
    required this.householdId,
    this.preSelectedContainerId,
  });

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen>
    with BaseScannerMixin, DuplicateCheckMixin, PostScanNavigationMixin, OcrMixin {

  // Local state
  ScanMode _currentMode = ScanMode.camera;
  String? _extractedText;

  @override
  String get householdId => widget.householdId;

  @override
  void initState() {
    super.initState();
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
    await _lookupItem(code);
  }

  // Handle manual ISBN entry
  Future<void> _handleManualEntry() async {
    final code = validateManualEntry();
    if (code == null) return;

    setState(() => isProcessing = true);
    await _lookupItem(code);
  }

  // Lookup item (tries vinyl first, then book)
  Future<void> _lookupItem(String code) async {
    try {
      final itemRepository = ref.read(itemRepositoryProvider);

      // Try vinyl lookup and duplicate check in parallel
      final results = await Future.wait([
        VinylLookupService.lookupByBarcode(code),
        itemRepository.findItemByBarcode(householdId, code),
      ]);

      if (!mounted) return;

      final vinylMetadata = results[0] as VinylMetadata?;
      var existingItem = results[1] as Item?;

      // Check for old items stored with discogsId in barcode field
      if (existingItem == null && vinylMetadata?.discogsId != null) {
        existingItem = await itemRepository.findItemByDiscogsId(
          householdId,
          vinylMetadata!.discogsId!,
        );
      }

      if (!mounted) return;

      if (vinylMetadata != null) {
        await _handleVinylFound(code, vinylMetadata, existingItem);
        return;
      }
    } catch (e) {
      // Vinyl lookup failed, continue to book lookup
    }

    // Fall back to book lookup
    await _lookupBook(code);
  }

  // Handle vinyl found
  Future<void> _handleVinylFound(
    String barcode,
    VinylMetadata vinylMetadata,
    Item? existingItem,
  ) async {
    try {
      if (!mounted) return;

      String? action;

      if (existingItem != null) {
        action = await handleDuplicateFlow(
          existingItem: existingItem,
          itemTypeName: 'Vinyl',
        );

        if (!mounted) return;

        if (action == 'addCopy') {
          action = await _showVinylPreview(vinylMetadata);
        } else {
          return; // User chose to scan next or cancelled
        }
      } else {
        action = await _showVinylPreview(vinylMetadata);
      }

      if (!mounted) return;

      await handlePostScanNavigation(
        action: action,
        addScreen: AddVinylScreen(
          householdId: householdId,
          vinylData: vinylMetadata,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
        successMessage: 'Vinyl added! Scan next item',
        itemLabel: 'Vinyl',
      );
    } catch (e) {
      if (!mounted) return;
      showError('Error processing vinyl: $e');
      resetScanning();
    }
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
        showError('No book found for ISBN: $isbn');
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
      creator: book.authors.isNotEmpty ? book.authorsDisplay : null,
      metadataFields: [
        if (book.publisher != null)
          ItemPreviewField(label: 'Publisher', value: book.publisher!),
        if (book.publishedDate != null)
          ItemPreviewField(label: 'Published', value: book.publishedDate!),
        if (book.pageCount != null)
          ItemPreviewField(label: 'Pages', value: book.pageCount.toString()),
        if (book.description != null)
          ItemPreviewField(label: '', value: book.description!),
      ],
      primaryActionLabel: 'Add Book',
      showCancelButton: false,
    );
  }

  // Show vinyl preview dialog
  Future<String?> _showVinylPreview(VinylMetadata vinyl) async {
    return showItemPreviewDialog(
      context: context,
      title: 'Vinyl Record Found',
      imageUrl: vinyl.coverUrl,
      fallbackIcon: Ionicons.disc_outline,
      itemTitle: vinyl.title,
      creator: vinyl.artist.isNotEmpty ? vinyl.artist : null,
      metadataFields: [
        if (vinyl.label != null)
          ItemPreviewField(label: 'Label', value: vinyl.label!),
        if (vinyl.year != null)
          ItemPreviewField(label: 'Year', value: vinyl.year.toString()),
        if (vinyl.catalogNumber != null)
          ItemPreviewField(label: 'Catalog #', value: vinyl.catalogNumber!),
        if (vinyl.genre != null)
          ItemPreviewField(label: 'Genre', value: vinyl.genre!),
        if (vinyl.format != null && vinyl.format!.isNotEmpty)
          ItemPreviewField(label: 'Format', value: vinyl.format!.join(', ')),
        if (vinyl.country != null)
          ItemPreviewField(label: 'Country', value: vinyl.country!),
      ],
      primaryActionLabel: 'Add Vinyl',
      showCancelButton: false,
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
          instructionText: 'Position barcode in frame to scan',
          scannedItemLabel: 'Items scanned',
        );

      case ScanMode.manual:
        return ManualEntryView(
          controller: manualIsbnController,
          labelText: 'ISBN or Barcode',
          hintText: '9780143127796',
          buttonText: 'Look Up',
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
          resultBuilder: (context, book) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: book.thumbnailUrl != null
                  ? Image.network(
                      book.thumbnailUrl!,
                      width: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Ionicons.book_outline),
                    )
                  : const Icon(Ionicons.book_outline),
              title: Text(book.title ?? 'Unknown Title'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (book.authors.isNotEmpty)
                    Text(book.authors.join(', ')),
                  if (book.publishedDate != null)
                    Text(
                      book.publishedDate!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              isThreeLine: true,
              trailing: const Icon(Ionicons.arrow_forward_outline),
              onTap: () => _handleSearchResultTap(book),
            ),
          ),
        );

      case ScanMode.photoOcr:
        return PhotoOcrView<BookMetadata>(
          title: 'Photo Search',
          description: 'Take a photo of a book cover or spine.\nWe\'ll extract text and search for matches.',
          isSearching: isSearching,
          extractedText: _extractedText,
          searchResults: searchResults.cast<BookMetadata>(),
          onCapturePhoto: _handlePhotoCapture,
          onResultTap: _handleSearchResultTap,
          resultBuilder: (context, book) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: book.thumbnailUrl != null
                  ? Image.network(
                      book.thumbnailUrl!,
                      width: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Ionicons.book_outline),
                    )
                  : const Icon(Ionicons.book_outline),
              title: Text(book.title ?? 'Unknown Title'),
              subtitle: book.authors.isNotEmpty
                  ? Text(book.authors.join(', '))
                  : null,
              trailing: const Icon(Ionicons.arrow_forward_outline),
            ),
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
              ScanMode.manual,
              ScanMode.textSearch,
              ScanMode.photoOcr,
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
