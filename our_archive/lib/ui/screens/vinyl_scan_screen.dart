import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/models/vinyl_metadata.dart';
import '../../data/models/item.dart';
import '../../providers/providers.dart';
import '../../services/vinyl_lookup_service.dart';
import '../../utils/text_search_helper.dart';
import '../widgets/common/item_found_dialog.dart';
import '../widgets/common/network_image_with_fallback.dart';
import '../widgets/common/search_results_view.dart';
import 'add_vinyl_screen.dart';

enum VinylScanMode { camera, textSearch }

class VinylScanScreen extends ConsumerStatefulWidget {
  final String householdId;
  final VinylScanMode initialMode;
  final String? preSelectedContainerId;

  const VinylScanScreen({
    super.key,
    required this.householdId,
    this.initialMode = VinylScanMode.camera,
    this.preSelectedContainerId,
  });

  @override
  ConsumerState<VinylScanScreen> createState() => _VinylScanScreenState();
}

class _VinylScanScreenState extends ConsumerState<VinylScanScreen> {
  late MobileScannerController _scannerController;
  final TextEditingController _textSearchController = TextEditingController();
  late VinylScanMode _currentMode;
  bool _isProcessing = false;
  String? _lastScannedCode;
  int _vinylsScanned = 0;
  List<VinylMetadata> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _textSearchController.dispose();
    super.dispose();
  }

  Future<void> _performTextSearch() async {
    await TextSearchHelper.performSearchWithState<VinylMetadata>(
      context: context,
      query: _textSearchController.text,
      searchFunction: (query) => VinylLookupService.searchByText(query),
      setState: setState,
      setIsSearching: (value) => _isSearching = value,
      setSearchResults: (results) => _searchResults = results,
      emptyMessage: 'No vinyl records found. Try a different search term.',
      itemTypeName: 'artist, album, or catalog number',
    );
  }

  Future<void> _handleSearchResultTap(VinylMetadata vinyl) async {
    // Note: Duplicate checking for search results could be added here
    // by checking discogsId or title/artist combination if needed

    // Navigate to AddVinylScreen
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVinylScreen(
          householdId: widget.householdId,
          vinylData: vinyl,
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

    await _lookupVinyl(code);
  }

  Future<void> _lookupVinyl(String barcode) async {
    try {
      final itemRepository = ref.read(itemRepositoryProvider);

      // Run API lookup and duplicate check in parallel for better performance
      final results = await Future.wait([
        VinylLookupService.lookupByBarcode(barcode),
        itemRepository.findItemByBarcode(widget.householdId, barcode),
      ]);

      if (!mounted) return;

      final vinylMetadata = results[0] as VinylMetadata?;
      var existingItem = results[1] as Item?;

      // If not found by barcode but we have discogsId from API, try searching by discogsId
      // This handles old items that were stored with discogsId in barcode field
      if (existingItem == null && vinylMetadata?.discogsId != null) {
        existingItem = await itemRepository.findItemByDiscogsId(
          widget.householdId,
          vinylMetadata!.discogsId!,
        );
      }

      if (!mounted) return;

      // If item exists in collection, show duplicate dialog first
      if (existingItem != null) {
        final existingNonNull = existingItem; // Capture non-null value for use after async
        final action = await _showDuplicateFoundDialog(existingNonNull, vinylMetadata);

        if (action == 'scanNext' || action == null) {
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
          return;
        } else if (action == 'addCopy') {
          // User wants to add another copy
          // If we don't have metadata from API, try to use existing item data
          if (vinylMetadata == null) {
            // Navigate directly to AddVinylScreen with existing item data
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddVinylScreen(
                  householdId: widget.householdId,
                  vinylData: VinylMetadata(
                    title: existingNonNull.title,
                    artist: existingNonNull.artist ?? '',
                    label: existingNonNull.label,
                    year: existingNonNull.releaseYear,
                    genre: existingNonNull.genre,
                    coverUrl: existingNonNull.coverUrl,
                    discogsId: existingNonNull.discogsId,
                    barcode: barcode,
                  ),
                  preSelectedContainerId: widget.preSelectedContainerId,
                ),
              ),
            );

            if (mounted) {
              setState(() {
                _vinylsScanned++;
                _isProcessing = false;
                _lastScannedCode = null;
              });
            }
            return;
          }
          // Otherwise continue with API metadata below
        }
      }

      // If no metadata found and not a duplicate, show error
      if (vinylMetadata == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Music not found for barcode: $barcode')),
        );
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
        return;
      }

      if (!mounted) return;

      // Show preview dialog (we already handled duplicates above)
      final action = await _showVinylPreview(vinylMetadata);

      if (!mounted) return;

      if (action == 'addVinyl') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddVinylScreen(
              householdId: widget.householdId,
              vinylData: vinylMetadata,
              preSelectedContainerId: widget.preSelectedContainerId,
            ),
          ),
        );

        // Navigation is handled by AddVinylScreen's popUntil
      } else if (action == 'scanNext') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddVinylScreen(
              householdId: widget.householdId,
              vinylData: vinylMetadata,
              preSelectedContainerId: widget.preSelectedContainerId,
            ),
          ),
        );

        if (mounted) {
          setState(() {
            _vinylsScanned++;
            _isProcessing = false;
            _lastScannedCode = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Music added! Scan next record ($_vinylsScanned scanned)'),
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
        SnackBar(content: Text('Error looking up vinyl: $e')),
      );
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  Future<String?> _showVinylPreview(VinylMetadata vinyl) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Music Found'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkImageWithFallback(
                imageUrl: vinyl.coverUrl,
                height: 200,
                fallbackIcon: Ionicons.disc_outline,
              ),
              const SizedBox(height: 16),
              Text(vinyl.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (vinyl.artist.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('by ${vinyl.artist}'),
              ],
              if (vinyl.label != null && vinyl.label!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Label: ${vinyl.label}'),
              ],
              if (vinyl.year != null) ...[
                const SizedBox(height: 8),
                Text('Year: ${vinyl.year}'),
              ],
              if (vinyl.format != null && vinyl.format!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Format: ${vinyl.format!.join(', ')}'),
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
            onPressed: () => Navigator.pop(context, 'addVinyl'),
            child: const Text('Add Music'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showDuplicateFoundDialog(Item existingItem, VinylMetadata? vinyl) async {
    return showItemFoundDialog(
      context: context,
      ref: ref,
      item: existingItem,
      householdId: widget.householdId,
      itemTypeName: 'Music',
      fallbackIcon: Ionicons.disc_outline,
      showAddCopyOption: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Music'),
        actions: [
          PopupMenuButton<VinylScanMode>(
            icon: const Icon(Ionicons.ellipsis_vertical_outline),
            onSelected: (mode) {
              setState(() {
                _currentMode = mode;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: VinylScanMode.camera,
                child: ListTile(
                  leading: Icon(Ionicons.qr_code_outline),
                  title: Text('Camera Scan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: VinylScanMode.textSearch,
                child: ListTile(
                  leading: Icon(Ionicons.search_outline),
                  title: Text('Search Discogs'),
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
      case VinylScanMode.camera:
        return _buildCameraScanner();
      case VinylScanMode.textSearch:
        return _buildTextSearch();
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
              _vinylsScanned > 0
                  ? 'Vinyl scanned: $_vinylsScanned\nPosition barcode in frame'
                  : 'Position barcode in frame',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextSearch() {
    return SearchResultsView<VinylMetadata>(
      controller: _textSearchController,
      labelText: 'Search Discogs',
      hintText: 'Artist, album, or catalog number',
      isSearching: _isSearching,
      searchResults: _searchResults,
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
  }
}
