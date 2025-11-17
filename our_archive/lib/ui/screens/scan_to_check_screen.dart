import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/vinyl_metadata.dart';
import '../../data/models/item.dart';
import '../../data/models/track.dart';
import '../../providers/providers.dart';
import '../../providers/music_providers.dart';
import '../../services/vinyl_lookup_service.dart';
import '../widgets/common/item_found_dialog.dart';
import '../widgets/scanner/item_not_found_dialog.dart';
import '../widgets/scanner/track_preview_section.dart';
import 'add_item_screen.dart';
import 'add_vinyl_screen.dart';

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
  List<Track>? _loadedTracks; // Store tracks loaded during preview

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

    // Detect barcode type - ISBN for books, UPC/EAN for vinyl
    if (_isIsbn(code)) {
      await _checkBook(code);
    } else {
      await _checkVinyl(code);
    }
  }

  bool _isIsbn(String code) {
    // Remove hyphens and spaces
    final cleaned = code.replaceAll(RegExp(r'[-\s]'), '');

    // ISBN-10 is 10 digits (possibly ending with X)
    // ISBN-13 is 13 digits and typically starts with 978 or 979
    if (cleaned.length == 10 && RegExp(r'^\d{9}[\dX]$').hasMatch(cleaned)) {
      return true;
    }
    if (cleaned.length == 13 && RegExp(r'^(978|979)\d{10}$').hasMatch(cleaned)) {
      return true;
    }

    return false;
  }

  Future<void> _handleManualEntry() async {
    final code = _manualIsbnController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an ISBN or barcode')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Detect barcode type - ISBN for books, UPC/EAN for vinyl
    if (_isIsbn(code)) {
      await _checkBook(code);
    } else {
      await _checkVinyl(code);
    }
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

        if (action == 'add') {
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

  Future<void> _checkVinyl(String barcode) async {
    try {
      final itemRepository = ref.read(itemRepositoryProvider);

      // Run collection check and API lookup in parallel for better performance
      final results = await Future.wait([
        itemRepository.findItemByBarcode(widget.householdId, barcode),
        VinylLookupService.lookupByBarcode(barcode),
      ]);

      if (!mounted) return;

      var existingItem = results[0] as Item?;
      final vinylMetadata = results[1] as VinylMetadata?;

      // If not found by barcode but we have discogsId from API, try searching by discogsId
      // This handles old items that were stored with discogsId in barcode field
      if (existingItem == null && vinylMetadata?.discogsId != null) {
        existingItem = await itemRepository.findItemByDiscogsId(
          widget.householdId,
          vinylMetadata!.discogsId!,
        );
      }

      if (!mounted) return;

      if (existingItem != null) {
        // Vinyl found in collection
        final action = await _showVinylFoundDialog(existingItem);

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
      } else if (vinylMetadata != null) {
        // Vinyl not found in collection but found in API
        // Show "not found" dialog with option to add
        final action = await _showVinylNotFoundDialog(vinylMetadata);

        if (!mounted) return;

        if (action == 'add') {
          // Navigate to AddVinylScreen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddVinylScreen(
                householdId: widget.householdId,
                vinylData: vinylMetadata,
                tracks: _loadedTracks, // Pass pre-loaded tracks
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
                content: Text('Music added! Scan next item to check'),
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
      } else {
        // Neither found in collection nor in API
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No music information found for barcode: $barcode'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking music: $e'),
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
    return showItemFoundDialog(
      context: context,
      ref: ref,
      item: item,
      householdId: widget.householdId,
      itemTypeName: 'Book',
      fallbackIcon: Ionicons.book_outline,
      showAddCopyOption: false,
    );
  }

  Future<String?> _showBookNotFoundDialog(BookMetadata book) async {
    return showItemNotFoundDialog(
      context: context,
      imageUrl: book.thumbnailUrl,
      fallbackIcon: Ionicons.book_outline,
      itemTitle: book.title ?? 'Unknown Title',
      creator: book.authors.isNotEmpty ? book.authorsDisplay : null,
      metadataFields: [
        if (book.publisher != null)
          ItemNotFoundField(label: 'Publisher', value: book.publisher!),
        if (book.publishedDate != null)
          ItemNotFoundField(label: 'Published', value: book.publishedDate!),
        if (book.pageCount != null)
          ItemNotFoundField(label: 'Pages', value: book.pageCount.toString()),
        if (book.description != null)
          ItemNotFoundField(
            label: '',
            value: book.description!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
      ],
      addActionLabel: 'Add to Collection',
    );
  }

  Future<String?> _showVinylFoundDialog(Item item) async {
    List<Track>? tracks = item.tracks; // Use cached tracks if available
    bool loadingTracks = tracks == null || tracks.isEmpty;

    // Load tracks asynchronously if not already cached
    final trackService = ref.read(trackServiceProvider);

    Future<void> loadTracks() async {
      if (tracks != null && (tracks?.isNotEmpty ?? false)) return; // Already have tracks

      try {
        final fetchedTracks = await trackService.getTracksForItem(item, widget.householdId);
        if (mounted) {
          tracks = fetchedTracks;
          loadingTracks = false;
        }
      } catch (e) {
        if (mounted) {
          loadingTracks = false;
        }
      }
    }

    // Start loading if needed
    if (loadingTracks) {
      loadTracks();
    }

    // Show dialog using StatefulBuilder to update when tracks load
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Update dialog when tracks load
          if (loadingTracks && (tracks == null || (tracks?.isEmpty ?? true))) {
            loadTracks().then((_) {
              if (mounted) setDialogState(() {});
            });
          }

          // Call the original showItemFoundDialog but build it manually
          // to work with StatefulBuilder
          return FutureBuilder<String>(
            future: _getContainerName(item),
            builder: (context, snapshot) {
              final locationText = snapshot.data ?? 'Loading location...';

              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Ionicons.checkmark_circle_outline, color: Colors.green, size: 28),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('You Already Have This!'),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover image
                      if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
                        Image.network(
                          item.coverUrl!,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Ionicons.disc_outline, size: 100, color: Colors.grey[400]),
                        )
                      else
                        Icon(Ionicons.disc_outline, size: 100, color: Colors.grey[400]),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),

                      // Artist
                      if (item.artist != null && item.artist!.isNotEmpty)
                        Text(
                          'By ${item.artist}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      const SizedBox(height: 16),

                      // Location container (highlighted)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Ionicons.location_outline,
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

                      // Quantity
                      if (item.quantity > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Quantity: ${item.quantity}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],

                      // Track preview section
                      TrackPreviewSection(
                        tracks: tracks,
                        isLoading: loadingTracks,
                        item: item,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'scanNext'),
                    child: const Text('Scan Next'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, 'close'),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _getContainerName(Item item) async {
    if (item.containerId == null) {
      return 'Not assigned to a container';
    }

    try {
      final containerService = ref.read(containerServiceProvider);
      final containers = await containerService.getAllContainers(widget.householdId).first;

      final container = containers.firstWhere(
        (c) => c.id == item.containerId,
        orElse: () => throw Exception('Container not found'),
      );

      return 'In: ${container.name}';
    } catch (e) {
      return 'Location unavailable';
    }
  }

  Future<String?> _showVinylNotFoundDialog(VinylMetadata vinyl) async {
    List<Track>? tracks;
    bool loadingTracks = true;

    // Create temporary item for track fetching
    final tempItem = Item(
      id: '', // Temporary ID
      title: vinyl.title,
      type: 'vinyl',
      location: '',
      tags: [],
      lastModified: DateTime.now(),
      createdAt: DateTime.now(),
      createdBy: '',
      searchText: vinyl.title.toLowerCase(),
      barcode: '',
      discogsId: vinyl.discogsId,
      artist: vinyl.artist.isNotEmpty ? vinyl.artist : null,
      label: vinyl.label,
      releaseYear: vinyl.year?.toString(),
      genre: vinyl.genre,
    );

    // Start loading tracks asynchronously
    final trackService = ref.read(trackServiceProvider);

    Future<void> loadTracks() async {
      try {
        final fetchedTracks = await trackService.getTracksForItem(tempItem, widget.householdId);
        if (mounted) {
          tracks = fetchedTracks;
          _loadedTracks = fetchedTracks; // Store for passing to AddVinylScreen
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

    // Show dialog with StatefulBuilder to update when tracks load
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

          return _buildVinylNotFoundDialog(
            context: dialogContext,
            vinyl: vinyl,
            tempItem: tempItem,
            tracks: tracks,
            isLoadingTracks: loadingTracks,
          );
        },
      ),
    );
  }

  AlertDialog _buildVinylNotFoundDialog({
    required BuildContext context,
    required VinylMetadata vinyl,
    required Item tempItem,
    List<Track>? tracks,
    bool isLoadingTracks = false,
  }) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Ionicons.information_circle_outline,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Not in Your Collection'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (vinyl.coverUrl != null && vinyl.coverUrl!.isNotEmpty)
              Image.network(
                vinyl.coverUrl!,
                height: 200,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Ionicons.disc_outline, size: 100, color: Colors.grey[400]),
              )
            else
              Icon(Ionicons.disc_outline, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 16),

            // Title
            Text(
              vinyl.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),

            // Artist
            if (vinyl.artist.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'By ${vinyl.artist}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],

            // Metadata fields
            if (vinyl.label != null && vinyl.label!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Label: ${vinyl.label!}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (vinyl.year != null) ...[
              const SizedBox(height: 4),
              Text(
                'Year: ${vinyl.year}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (vinyl.format != null && vinyl.format!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Format: ${vinyl.format!.join(', ')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],

            // Track preview section
            TrackPreviewSection(
              tracks: tracks,
              isLoading: isLoadingTracks,
              item: tempItem,
            ),
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
          onPressed: () => Navigator.pop(context, 'add'),
          icon: const Icon(Ionicons.add_outline),
          label: const Text('Add to Collection'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan to Check Items - ${widget.householdName}'),
        actions: [
          IconButton(
            icon: Icon(_scannerController.torchEnabled
                ? Ionicons.flash_outline
                : Ionicons.flash_off_outline),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: Icon(_showManualEntry ? Ionicons.qr_code_outline : Ionicons.keypad_outline),
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
                    const Icon(Ionicons.qr_code_outline, size: 100),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _manualIsbnController,
                      decoration: const InputDecoration(
                        labelText: 'Enter ISBN or Barcode',
                        hintText: '9780143127796 or UPC',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Ionicons.keypad_outline),
                      ),
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      onSubmitted: (_) => _handleManualEntry(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isProcessing ? null : _handleManualEntry,
                      icon: const Icon(Ionicons.search_outline),
                      label: const Text('Check Item'),
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
                        Text('Checking item...'),
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
