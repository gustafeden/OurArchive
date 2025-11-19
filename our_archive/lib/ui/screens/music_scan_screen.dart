import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/music_metadata.dart';
import '../../data/models/item.dart';
import '../../data/models/track.dart';
import '../../data/models/discogs_search_result.dart';
import '../../providers/providers.dart';
import '../../providers/music_providers.dart';
import '../../services/music_lookup_service.dart';
import '../../utils/text_search_helper.dart';
import '../widgets/common/search_results_view.dart';
import '../widgets/scanner/camera_scanner_view.dart';
import '../widgets/scanner/scan_mode_selector.dart';
import '../widgets/scanner/track_preview_section.dart';
import '../widgets/scanner/music_selection_dialog.dart';
import 'mixins/base_scanner_mixin.dart';
import 'mixins/duplicate_check_mixin.dart';
import 'mixins/post_scan_navigation_mixin.dart';
import 'common/scan_modes.dart';
import 'add_music_screen.dart';

class MusicScanScreen extends ConsumerStatefulWidget {
  final String householdId;
  final ScanMode initialMode;
  final String? preSelectedContainerId;

  const MusicScanScreen({
    super.key,
    required this.householdId,
    this.initialMode = ScanMode.camera,
    this.preSelectedContainerId,
  });

  @override
  ConsumerState<MusicScanScreen> createState() => _MusicScanScreenState();
}

class _MusicScanScreenState extends ConsumerState<MusicScanScreen>
    with BaseScannerMixin, DuplicateCheckMixin, PostScanNavigationMixin {

  late ScanMode _currentMode;
  List<Track>? _loadedTracks; // Store tracks loaded during preview

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

  // Text search for music
  Future<void> _performTextSearch() async {
    await TextSearchHelper.performSearchWithState<MusicMetadata>(
      context: context,
      query: textSearchController.text,
      searchFunction: (query) => MusicLookupService.searchByText(query),
      setState: setState,
      setIsSearching: (value) => isSearching = value,
      setSearchResults: (results) => searchResults = results,
      emptyMessage: 'No music found. Try a different search term.',
      itemTypeName: 'artist, album, or catalog number',
    );
  }

  // Handle tapping a search result
  Future<void> _handleSearchResultTap(MusicMetadata music) async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMusicScreen(
          householdId: householdId,
          musicData: music,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
      ),
    );
  }

  // Handle barcode detection from camera
  Future<void> _handleBarcode(String code) async {
    if (!shouldProcessBarcode(code)) return;

    startProcessing(code);
    await _lookupMusic(code);
  }

  // Lookup music by barcode
  Future<void> _lookupMusic(String barcode) async {
    try {
      final itemRepository = ref.read(itemRepositoryProvider);

      // Run API lookup with pagination and find ALL owned items in parallel
      final results = await Future.wait([
        MusicLookupService.lookupByBarcodeWithPagination(barcode),
        itemRepository.findAllItemsByBarcode(householdId, barcode),
      ]);

      if (!mounted) return;

      final searchResult = results[0] as DiscogsSearchResult;
      final ownedItems = results[1] as List<Item>;

      // If no results found, show error
      if (searchResult.results.isEmpty) {
        showError('Music not found for barcode: $barcode');
        resetScanning();
        return;
      }

      // Show selection dialog (always, even for single result, to show owned status)
      final selectionResult = await showMusicSelectionDialog(
        context: context,
        barcode: barcode,
        initialResults: searchResult.results,
        initialPagination: searchResult.pagination,
        ownedItems: ownedItems,
        householdId: householdId,
      );

      // User cancelled selection
      if (selectionResult == null) {
        resetScanning();
        return;
      }

      // Extract music metadata from result
      final musicMetadata = selectionResult.music;

      if (!mounted) return;

      // Check if this specific release is owned
      final ownedItem = ownedItems.cast<Item?>().firstWhere(
        (item) => item?.discogsId == musicMetadata.discogsId,
        orElse: () => null,
      );

      // Handle duplicate (if this specific release is owned)
      if (ownedItem != null) {
        final action = await handleDuplicateFlow(
          existingItem: ownedItem,
          itemTypeName: 'Music',
        );

        if (action == 'addCopy') {
          // Continue with the selected metadata
        } else {
          return; // User chose to scan next or cancelled
        }
      }

      if (!mounted) return;

      // Load tracks in parallel with showing preview
      // Create temporary item for track fetching
      final tempItem = Item(
        id: '', // Temporary ID
        title: musicMetadata.title,
        type: 'music',
        location: '',
        tags: [],
        lastModified: DateTime.now(),
        createdAt: DateTime.now(),
        createdBy: '',
        searchText: musicMetadata.title.toLowerCase(),
        barcode: barcode,
        discogsId: musicMetadata.discogsId,
        artist: musicMetadata.artist.isNotEmpty ? musicMetadata.artist : null,
        label: musicMetadata.label,
        releaseYear: musicMetadata.year?.toString(),
        genre: musicMetadata.genre,
      );

      // Show preview dialog with track loading
      final action = await _showMusicPreview(musicMetadata, tempItem);

      if (!mounted) return;

      await handlePostScanNavigation(
        action: action,
        addScreen: AddMusicScreen(
          householdId: householdId,
          musicData: musicMetadata,
          preSelectedContainerId: widget.preSelectedContainerId,
          tracks: _loadedTracks, // Pass pre-loaded tracks
        ),
        successMessage: 'Music added! Scan next record',
        itemLabel: 'Music',
      );
    } catch (e) {
      if (!mounted) return;
      showError('Error looking up music: $e');
      resetScanning();
    }
  }

  // Show music preview dialog with track loading
  Future<String?> _showMusicPreview(MusicMetadata music, Item tempItem) async {
    List<Track>? tracks;
    bool loadingTracks = true;

    // Start loading tracks (CoverFlow pattern)
    final trackService = ref.read(trackServiceProvider);

    // Load tracks asynchronously
    Future<void> loadTracks() async {
      try {
        final fetchedTracks = await trackService.getTracksForItem(tempItem, householdId);
        if (mounted) {
          tracks = fetchedTracks;
          _loadedTracks = fetchedTracks; // Store for passing to AddMusicScreen
          loadingTracks = false;
        }
      } catch (e) {
        if (mounted) {
          loadingTracks = false;
        }
      }
    }

    // Start loading immediately
    loadTracks();

    // Show dialog with loading state
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          // Update dialog when tracks load
          if (loadingTracks && tracks == null) {
            loadTracks().then((_) {
              if (mounted) setState(() {});
            });
          }

          return AlertDialog(
            title: const Text('Music Found'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use ItemPreviewDialog's content structure
                  _buildPreviewContent(music, tempItem, tracks, loadingTracks),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'scanNext'),
                child: const Text('Scan Next'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, 'add'),
                child: const Text('Add Music'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreviewContent(MusicMetadata music, Item tempItem, List<Track>? tracks, bool loadingTracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover image
        if (music.coverUrl != null)
          Image.network(
            music.coverUrl!,
            height: 200,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Ionicons.disc_outline, size: 100, color: Colors.grey[400]),
          )
        else
          Icon(Ionicons.disc_outline, size: 100, color: Colors.grey[400]),
        const SizedBox(height: 16),

        // Title
        Text(
          music.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        // Artist
        if (music.artist.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'by ${music.artist}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],

        // Metadata fields
        const SizedBox(height: 8),
        if (music.label != null && music.label!.isNotEmpty)
          Text('Label: ${music.label!}'),
        if (music.year != null)
          Text('Year: ${music.year}'),
        if (music.format != null && music.format!.isNotEmpty)
          Text('Format: ${music.format!.join(', ')}'),

        // Track preview section
        TrackPreviewSection(
          tracks: tracks,
          isLoading: loadingTracks,
          item: tempItem,
        ),
      ],
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
          scannedItemLabel: 'Music scanned',
        );

      case ScanMode.textSearch:
        return SearchResultsView<MusicMetadata>(
          controller: textSearchController,
          labelText: 'Search Discogs',
          hintText: 'Artist, album, or catalog number',
          isSearching: isSearching,
          searchResults: searchResults.cast<MusicMetadata>(),
          onSearch: _performTextSearch,
          resultBuilder: (context, music) => ListTile(
            leading: music.coverUrl != null && music.coverUrl!.isNotEmpty
                ? Image.network(music.coverUrl!, width: 40, fit: BoxFit.cover)
                : const Icon(Ionicons.disc_outline),
            title: Text(music.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (music.artist.isNotEmpty) Text(music.artist),
                if (music.format != null && music.format!.isNotEmpty)
                  Text(
                    music.format!.join(', '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            onTap: () => _handleSearchResultTap(music),
          ),
        );

      case ScanMode.manual:
      case ScanMode.photoOcr:
        // These modes are not supported for music scanning
        return const Center(
          child: Text('This scan mode is not available for music'),
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
