import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/models/vinyl_metadata.dart';
import '../../data/models/item.dart';
import '../../providers/providers.dart';
import '../../services/vinyl_lookup_service.dart';
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
    final query = _textSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter artist, album, or catalog number')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await VinylLookupService.searchByText(query);

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No vinyl records found. Try a different search term.')),
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
      final vinylMetadata = await VinylLookupService.lookupByBarcode(barcode);

      if (!mounted) return;

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

      // Check for duplicate
      final itemRepository = ref.read(itemRepositoryProvider);
      final existingItem = await itemRepository.findItemByBarcode(
        widget.householdId,
        barcode,
      );

      if (!mounted) return;

      if (existingItem != null) {
        final action = await _showDuplicateFoundDialog(existingItem, vinylMetadata);

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

        if (mounted) {
          Navigator.pop(context);
        }
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
              content: Text('Vinyl added! Scan next record ($_vinylsScanned scanned)'),
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
              if (vinyl.coverUrl != null && vinyl.coverUrl!.isNotEmpty)
                Center(
                  child: Image.network(
                    vinyl.coverUrl!,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.album, size: 100),
                  ),
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

  Future<String?> _showDuplicateFoundDialog(Item existingItem, VinylMetadata vinyl) async {
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
        title: const Text('Music Already Exists'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This music is already in your collection:',
              style: TextStyle(fontWeight: FontWeight.bold),
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
        title: const Text('Scan Music'),
        actions: [
          PopupMenuButton<VinylScanMode>(
            icon: const Icon(Icons.more_vert),
            onSelected: (mode) {
              setState(() {
                _currentMode = mode;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: VinylScanMode.camera,
                child: ListTile(
                  leading: Icon(Icons.qr_code_scanner),
                  title: Text('Camera Scan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: VinylScanMode.textSearch,
                child: ListTile(
                  leading: Icon(Icons.search),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Discogs',
                        hintText: 'Artist, album, or catalog number',
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
                final vinyl = _searchResults[index];
                return ListTile(
                  leading: vinyl.coverUrl != null && vinyl.coverUrl!.isNotEmpty
                      ? Image.network(vinyl.coverUrl!, width: 40, fit: BoxFit.cover)
                      : const Icon(Icons.album),
                  title: Text(vinyl.title),
                  subtitle: vinyl.artist.isNotEmpty ? Text(vinyl.artist) : null,
                  onTap: () => _handleSearchResultTap(vinyl),
                );
              },
            ),
          ),
      ],
    );
  }
}
