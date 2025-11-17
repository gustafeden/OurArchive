import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/vinyl_metadata.dart';
import '../../data/models/item.dart';
import '../../providers/providers.dart';
import '../../services/vinyl_lookup_service.dart';
import '../../utils/text_search_helper.dart';
import '../widgets/common/search_results_view.dart';
import '../widgets/scanner/item_preview_dialog.dart';
import '../widgets/scanner/camera_scanner_view.dart';
import '../widgets/scanner/scan_mode_selector.dart';
import 'mixins/base_scanner_mixin.dart';
import 'mixins/duplicate_check_mixin.dart';
import 'mixins/post_scan_navigation_mixin.dart';
import 'common/scan_modes.dart';
import 'add_vinyl_screen.dart';

class VinylScanScreen extends ConsumerStatefulWidget {
  final String householdId;
  final ScanMode initialMode;
  final String? preSelectedContainerId;

  const VinylScanScreen({
    super.key,
    required this.householdId,
    this.initialMode = ScanMode.camera,
    this.preSelectedContainerId,
  });

  @override
  ConsumerState<VinylScanScreen> createState() => _VinylScanScreenState();
}

class _VinylScanScreenState extends ConsumerState<VinylScanScreen>
    with BaseScannerMixin, DuplicateCheckMixin, PostScanNavigationMixin {

  late ScanMode _currentMode;

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
    super.dispose();
  }

  // Text search for vinyl
  Future<void> _performTextSearch() async {
    await TextSearchHelper.performSearchWithState<VinylMetadata>(
      context: context,
      query: textSearchController.text,
      searchFunction: (query) => VinylLookupService.searchByText(query),
      setState: setState,
      setIsSearching: (value) => isSearching = value,
      setSearchResults: (results) => searchResults = results,
      emptyMessage: 'No vinyl records found. Try a different search term.',
      itemTypeName: 'artist, album, or catalog number',
    );
  }

  // Handle tapping a search result
  Future<void> _handleSearchResultTap(VinylMetadata vinyl) async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVinylScreen(
          householdId: householdId,
          vinylData: vinyl,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
      ),
    );
  }

  // Handle barcode detection from camera
  Future<void> _handleBarcode(String code) async {
    if (!shouldProcessBarcode(code)) return;

    startProcessing(code);
    await _lookupVinyl(code);
  }

  // Lookup vinyl by barcode
  Future<void> _lookupVinyl(String barcode) async {
    try {
      final itemRepository = ref.read(itemRepositoryProvider);

      // Run API lookup and duplicate check in parallel
      final results = await Future.wait([
        VinylLookupService.lookupByBarcode(barcode),
        itemRepository.findItemByBarcode(householdId, barcode),
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

      // Handle duplicate
      if (existingItem != null) {
        final action = await handleDuplicateFlow(
          existingItem: existingItem,
          itemTypeName: 'Music',
        );

        if (action == 'addCopy') {
          // If we don't have metadata from API, use existing item data
          if (vinylMetadata == null) {
            final vinylData = VinylMetadata(
              title: existingItem.title,
              artist: existingItem.artist ?? '',
              label: existingItem.label,
              year: existingItem.releaseYear,
              genre: existingItem.genre,
              coverUrl: existingItem.coverUrl,
              discogsId: existingItem.discogsId,
              barcode: barcode,
            );

            await handlePostScanNavigation(
              action: 'scanNext', // Always scan next when adding copy
              addScreen: AddVinylScreen(
                householdId: householdId,
                vinylData: vinylData,
                preSelectedContainerId: widget.preSelectedContainerId,
              ),
              successMessage: 'Music added! Scan next record',
              itemLabel: 'Music',
            );
            return;
          }
          // Otherwise continue with API metadata
        } else {
          return; // User chose to scan next or cancelled
        }
      }

      // If no metadata found and not a duplicate, show error
      if (vinylMetadata == null) {
        showError('Music not found for barcode: $barcode');
        resetScanning();
        return;
      }

      if (!mounted) return;

      // Show preview dialog
      final action = await _showVinylPreview(vinylMetadata);

      if (!mounted) return;

      await handlePostScanNavigation(
        action: action,
        addScreen: AddVinylScreen(
          householdId: householdId,
          vinylData: vinylMetadata,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
        successMessage: 'Music added! Scan next record',
        itemLabel: 'Music',
      );
    } catch (e) {
      if (!mounted) return;
      showError('Error looking up vinyl: $e');
      resetScanning();
    }
  }

  // Show vinyl preview dialog
  Future<String?> _showVinylPreview(VinylMetadata vinyl) async {
    return showItemPreviewDialog(
      context: context,
      title: 'Music Found',
      imageUrl: vinyl.coverUrl,
      fallbackIcon: Ionicons.disc_outline,
      itemTitle: vinyl.title,
      creator: vinyl.artist.isNotEmpty ? vinyl.artist : null,
      metadataFields: [
        if (vinyl.label != null && vinyl.label!.isNotEmpty)
          ItemPreviewField(label: 'Label', value: vinyl.label!),
        if (vinyl.year != null)
          ItemPreviewField(label: 'Year', value: vinyl.year.toString()),
        if (vinyl.format != null && vinyl.format!.isNotEmpty)
          ItemPreviewField(label: 'Format', value: vinyl.format!.join(', ')),
      ],
      primaryActionLabel: 'Add Music',
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
          instructionText: 'Position barcode in frame',
          scannedItemLabel: 'Vinyl scanned',
        );

      case ScanMode.textSearch:
        return SearchResultsView<VinylMetadata>(
          controller: textSearchController,
          labelText: 'Search Discogs',
          hintText: 'Artist, album, or catalog number',
          isSearching: isSearching,
          searchResults: searchResults.cast<VinylMetadata>(),
          onSearch: _performTextSearch,
          resultBuilder: (context, vinyl) => ListTile(
            leading: vinyl.coverUrl != null && vinyl.coverUrl!.isNotEmpty
                ? Image.network(vinyl.coverUrl!, width: 40, fit: BoxFit.cover)
                : const Icon(Ionicons.disc_outline),
            title: Text(vinyl.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vinyl.artist.isNotEmpty) Text(vinyl.artist),
                if (vinyl.format != null && vinyl.format!.isNotEmpty)
                  Text(
                    vinyl.format!.join(', '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            onTap: () => _handleSearchResultTap(vinyl),
          ),
        );

      case ScanMode.manual:
      case ScanMode.photoOcr:
        // These modes are not supported for vinyl scanning
        return const Center(
          child: Text('This scan mode is not available for vinyl'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentMode.getTitle(itemType: 'Music')),
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
              ScanMode.textSearch,
            ],
            onModeSelected: (mode) {
              setState(() {
                _currentMode = mode;
                searchResults = [];
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
