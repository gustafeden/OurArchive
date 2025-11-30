import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/coverflow/coverflow_controller.dart';
import '../widgets/coverflow/coverflow_viewport.dart';
import '../widgets/coverflow/coverflow_background.dart';
import '../widgets/coverflow/track_overlay_panel.dart';
import '../../data/models/item.dart';
import '../../data/models/track.dart';
import '../../providers/music_providers.dart';
import '../../providers/providers.dart';
import '../../providers/theme_provider.dart';
import 'item_detail_screen.dart';

/// iPod-style CoverFlow music browser
class CoverFlowMusicBrowser extends ConsumerStatefulWidget {
  final String? householdId; // null = all households

  const CoverFlowMusicBrowser({
    super.key,
    this.householdId,
  });

  @override
  ConsumerState<CoverFlowMusicBrowser> createState() => _CoverFlowMusicBrowserState();
}

class _CoverFlowMusicBrowserState extends ConsumerState<CoverFlowMusicBrowser>
    with TickerProviderStateMixin {
  CoverFlowController? _controller;
  List<Track>? _currentTracks;
  bool _loadingTracks = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final musicItemsAsync = widget.householdId == null
        ? ref.watch(allMusicItemsProvider)
        : ref.watch(householdMusicItemsProvider(widget.householdId!));

    return musicItemsAsync.when(
      loading: () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Music'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Music'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: Text('Error: $error')),
      ),
      data: (allMusicItems) {
        // Apply filters
        final musicItems = ref.watch(
          filteredMusicItemsProvider(widget.householdId),
        );

        if (musicItems.isEmpty) {
          return Scaffold(
            extendBody: true,
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text(widget.householdId == null ? 'All Music' : 'Music'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(
              child: Text('No music found', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        // Initialize controller if needed
        if (_controller == null || _controller!.itemCount != musicItems.length) {
          _controller?.dispose();
          _controller = CoverFlowController(
            itemCount: musicItems.length,
            vsync: this,
          );
          _controller!.addListener(_onControllerChanged);
        }

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(widget.householdId == null ? 'All Music' : 'Music'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _buildBody(musicItems),
        );
      },
    );
  }

  Widget _buildBody(List<Item> musicItems) {
    final backgroundStyle = ref.watch(coverFlowBackgroundStyleProvider);
    final blurredAlbumEnabled = ref.watch(blurredAlbumEffectProvider);
    final centerIndex = _controller!.centeredIndex.clamp(0, musicItems.length - 1);
    final currentItem = centerIndex < musicItems.length ? musicItems[centerIndex] : null;

    return Stack(
      children: [
        // Background layer
        Positioned.fill(
          child: CoverFlowBackground(
            style: backgroundStyle,
            currentItem: currentItem,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Blurred album effect layer (if enabled)
        if (blurredAlbumEnabled)
          Positioned.fill(
            child: BlurredAlbumBackground(
              item: currentItem,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

        // CoverFlow viewport
        CoverFlowViewport(
          items: musicItems,
          controller: _controller!,
          householdId: widget.householdId,
          onItemLongPress: _handleItemLongPress,
        ),

        // Dim overlay - ignore pointer when not visible!
        IgnorePointer(
          ignoring: !_controller!.overlayVisible,
          child: AnimatedOpacity(
            opacity: _controller!.overlayVisible ? 0.2 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: GestureDetector(
              onTap: () {
                // Tap on dim overlay closes the panel
                setState(() {
                  _currentTracks = null;
                });
                _controller!.hideTrackOverlay();
              },
              child: Container(
                color: Colors.black,
              ),
            ),
          ),
        ),

        // Track overlay panel
        if (_controller!.overlayVisible && _controller!.centerCoverRect != null)
          _buildTrackOverlay(musicItems),
      ],
    );
  }

  Widget _buildTrackOverlay(List<Item> musicItems) {
    final centerIndex = _controller!.centeredIndex.clamp(0, musicItems.length - 1);
    final item = musicItems[centerIndex];
    final centerRect = _controller!.centerCoverRect!;

    final overlayWidth = centerRect.width * 1.2;
    final overlayHeight = centerRect.height * 1.35;

    return Positioned(
      left: centerRect.center.dx - (overlayWidth / 2),
      top: centerRect.center.dy - (overlayHeight / 2),
      child: GestureDetector(
        onTap: () {}, // Prevent tap-through
        child: AnimatedOpacity(
          opacity: _controller!.overlayVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: TrackOverlayPanel(
            item: item,
            tracks: _currentTracks,
            isLoading: _loadingTracks,
            width: overlayWidth,
            height: overlayHeight,
            onClose: () {
              setState(() {
                _currentTracks = null;
              });
              _controller!.hideTrackOverlay();
            },
          ),
        ),
      ),
    );
  }

  void _onControllerChanged() {
    if (!mounted) return;

    // Only load tracks when overlay becomes visible
    if (_controller!.overlayVisible && !_loadingTracks && _currentTracks == null) {
      // Set loading state immediately to prevent brief error screen
      setState(() {
        _loadingTracks = true;
      });
      // Defer track loading to avoid blocking UI
      Future.microtask(() => _loadTracksForCurrentItem());
      return; // Return early - setState above already triggered rebuild
    }

    // Always use post-frame callback to be safe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadTracksForCurrentItem() async {
    try {
      final musicItems = ref.read(
        filteredMusicItemsProvider(widget.householdId),
      );

      if (musicItems.isEmpty) return;

      final centerIndex = _controller!.centeredIndex.clamp(0, musicItems.length - 1);
      final item = musicItems[centerIndex];

      // If item already has tracks, use them
      if (item.tracks != null && item.tracks!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _currentTracks = item.tracks;
            _loadingTracks = false;
          });
        }
        return;
      }

      // Otherwise, fetch from service
      if (mounted) {
        setState(() {
          _loadingTracks = true;
          _currentTracks = null;
        });
      }

      final trackService = ref.read(trackServiceProvider);

      // Need to get household ID for the item
      // For simplicity, we'll use the first household if we're in "all music" mode
      String householdId = widget.householdId ?? '';

      if (householdId.isEmpty) {
        final households = await ref.read(userHouseholdsProvider.future);
        if (households.isNotEmpty) {
          householdId = households.first.id;
        }
      }

      if (householdId.isEmpty) {
        if (mounted) {
          setState(() {
            _currentTracks = [];
            _loadingTracks = false;
          });
        }
        return;
      }

      final tracks = await trackService.getTracksForItem(item, householdId);

      if (mounted) {
        setState(() {
          _currentTracks = tracks;
          _loadingTracks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentTracks = [];
          _loadingTracks = false;
        });
      }
    }
  }

  void _handleItemLongPress(Item item, String householdId) async {
    // Close overlay if open
    if (_controller!.overlayVisible) {
      _controller!.hideTrackOverlay();
    }

    // Fetch household object
    final households = await ref.read(userHouseholdsProvider.future);
    final household = households.firstWhere(
      (h) => h.id == householdId,
      orElse: () => households.first,
    );

    if (!mounted) return;

    // Navigate to item detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(
          item: item,
          household: household,
        ),
      ),
    );
  }
}
