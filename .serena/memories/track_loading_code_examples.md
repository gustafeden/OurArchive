# CoverFlow Track Loading - Detailed Code Examples

## File: coverflow_music_browser.dart (Lines 187-256)

### The Complete _loadTracksForCurrentItem() Method

```dart
Future<void> _loadTracksForCurrentItem() async {
  try {
    final musicItems = ref.read(
      filteredMusicItemsProvider(widget.householdId),
    );

    if (musicItems.isEmpty) return;

    final centerIndex = _controller!.centeredIndex.clamp(0, musicItems.length - 1);
    final item = musicItems[centerIndex];

    // STEP 1: Check if item already has cached tracks
    if (item.tracks != null && item.tracks!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _currentTracks = item.tracks;
          _loadingTracks = false;
        });
      }
      return;  // Early return - no need to fetch
    }

    // STEP 2: Set loading state before async work
    if (mounted) {
      setState(() {
        _loadingTracks = true;
        _currentTracks = null;
      });
    }

    // STEP 3: Get household ID (needed for TrackService)
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

    // STEP 4: Call TrackService (the magic happens here)
    final trackService = ref.read(trackServiceProvider);
    final tracks = await trackService.getTracksForItem(item, householdId);

    // STEP 5: Update UI with results
    if (mounted) {
      setState(() {
        _currentTracks = tracks;
        _loadingTracks = false;
      });
    }
  } catch (e, stackTrace) {
    // STEP 6: Graceful error handling
    if (mounted) {
      setState(() {
        _currentTracks = [];
        _loadingTracks = false;
      });
    }
  }
}
```

### How It's Triggered: _onControllerChanged() (Lines 165-185)

```dart
void _onControllerChanged() {
  if (!mounted) return;

  // Only load tracks when overlay becomes visible (not on every scroll)
  if (_controller!.overlayVisible && !_loadingTracks && _currentTracks == null) {
    // Set loading state immediately to prevent brief error screen
    setState(() {
      _loadingTracks = true;
    });
    
    // Defer track loading to avoid blocking UI
    // This queues the operation for the next microtask cycle
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
```

---

## File: track_service.dart (Lines 16-60)

### The Complete getTracksForItem() Method

```dart
/// Get tracks for an item, fetching from Discogs if needed
/// Returns cached tracks if available, otherwise fetches from Discogs API
/// Also enriches tracks with iTunes preview URLs
Future<List<Track>> getTracksForItem(Item item, String householdId) async {
  
  // ============================================
  // CACHE LEVEL 1: Check Firestore cache first
  // ============================================
  
  if (item.tracks != null && item.tracks!.isNotEmpty) {
    // Check if tracks already have preview URLs (fully enriched)
    final hasPreviewUrls = item.tracks!.any((t) => t.previewUrl != null);
    
    if (hasPreviewUrls) {
      // Tracks are complete - return immediately
      return item.tracks!;
    }

    // Tracks exist but missing preview URLs - need to enrich them
    try {
      final tracksWithPreviews = await enrichTracksWithPreviews(item.tracks!, item);
      if (tracksWithPreviews.isNotEmpty) {
        // Save enriched tracks back to Firestore
        await cacheTracksToItem(householdId, item.id, tracksWithPreviews);
      }
      return tracksWithPreviews;
    } catch (e) {
      print('Error enriching tracks with previews: $e');
      // Graceful fallback: return tracks without previews
      return item.tracks!;
    }
  }

  // ============================================
  // CACHE LEVEL 2: Check if Discogs ID available
  // ============================================
  
  if (item.discogsId == null || item.discogsId!.isEmpty) {
    return []; // Cannot fetch without Discogs ID
  }

  try {
    // ============================================
    // FETCH FROM DISCOGS API
    // ============================================
    
    final tracks = await fetchTracksFromDiscogs(item.discogsId!);

    // ============================================
    // ENRICH WITH ITUNES PREVIEWS
    // ============================================
    
    final tracksWithPreviews = await enrichTracksWithPreviews(tracks, item);

    // ============================================
    // SAVE TO FIRESTORE (persistent cache)
    // ============================================
    
    if (tracksWithPreviews.isNotEmpty) {
      await cacheTracksToItem(householdId, item.id, tracksWithPreviews);
    }

    return tracksWithPreviews;
  } catch (e) {
    // Log error but don't throw - gracefully return empty list
    print('Error fetching tracks for item ${item.id}: $e');
    return [];
  }
}
```

### Helper: cacheTracksToItem() (Lines 104-116)

```dart
/// Cache tracks to the item in Firestore
Future<void> cacheTracksToItem(String householdId, String itemId, List<Track> tracks) async {
  try {
    // Use the item repository to update the item with tracks
    await _itemRepository.updateItemTracks(
      householdId: householdId,
      itemId: itemId,
      tracks: tracks,
    );
  } catch (e) {
    print('Error caching tracks to item $itemId: $e');
    // Don't throw - caching failure shouldn't break the UI
  }
}
```

### Helper: fetchTracksFromDiscogs() (Lines 63-101)

```dart
/// Fetch track listing from Discogs API
Future<List<Track>> fetchTracksFromDiscogs(String discogsId) async {
  try {
    final releaseDetails = await DiscogsService.getReleaseDetails(discogsId);

    if (releaseDetails == null) {
      return [];
    }

    final tracklist = releaseDetails['tracklist'] as List<dynamic>?;
    if (tracklist == null || tracklist.isEmpty) {
      return [];
    }

    // Transform raw API data to Track objects
    return tracklist.map((trackData) {
      final trackMap = trackData as Map<String, dynamic>;

      // Determine side from position (e.g., "A1" -> "A", "B3" -> "B")
      final position = trackMap['position'] as String? ?? '';
      String? side;
      if (position.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(position)) {
        side = position[0]; // First character is the side
      }

      return Track(
        position: position,
        title: trackMap['title'] as String? ?? '',
        duration: trackMap['duration'] as String?,
        side: side,
        // Discogs can have artists per track for compilations
        artist: (trackMap['artists'] as List<dynamic>?)
            ?.map((a) => (a as Map<String, dynamic>)['name'] as String)
            .join(', '),
      );
    }).toList();
  } catch (e) {
    print('Error parsing Discogs tracklist: $e');
    return [];
  }
}
```

### Helper: enrichTracksWithPreviews() (Lines 119-147)

```dart
/// Enrich tracks with preview URLs from iTunes/Apple Music
Future<List<Track>> enrichTracksWithPreviews(List<Track> tracks, Item item) async {
  if (tracks.isEmpty) {
    return tracks;
  }

  try {
    print('[TrackService] Fetching iTunes previews for: ${item.title} by ${item.artist}');

    // Search iTunes for preview URLs
    final previewMap = await ITunesSearchService.searchAlbumPreviews(
      albumName: item.title,
      artistName: item.artist,
    );

    // Match tracks with previews
    final enrichedTracks = ITunesSearchService.matchTracksWithPreviews(
      tracks,
      previewMap,
    );

    final previewCount = enrichedTracks.where((t) => t.previewUrl != null).length;
    print('[TrackService] Matched $previewCount/${tracks.length} tracks with previews');

    return enrichedTracks;
  } catch (e) {
    print('[TrackService] Error enriching tracks: $e');
    return tracks; // Return original tracks on error
  }
}
```

---

## File: item_repository.dart (Lines 359-379)

### The updateItemTracks() Method

```dart
/// Update tracks for an item (lightweight update without version check)
Future<void> updateItemTracks({
  required String householdId,
  required String itemId,
  required List<Track> tracks,
}) async {
  try {
    final docRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .doc(itemId);

    await docRef.update({
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'lastModified': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    // Log error but don't throw - track caching is not critical
    print('Error updating tracks for item $itemId: $e');
  }
}
```

**Why No Transactions?**
- Tracks are enrichment data, not core item data
- Conflict resolution: "last write wins" is acceptable
- Performance: Direct update is faster than transaction
- Resilience: Silent failure is appropriate for non-critical data

---

## File: track_overlay_panel.dart - UI States

### Display Logic (Lines 64-70)

```dart
// Track list or loading indicator
Expanded(
  child: isLoading
      ? _buildLoadingState()  // Show spinner
      : (tracks == null || tracks!.isEmpty)
          ? _buildNoTracksState(context)  // Show "No tracks"
          : _buildTrackList(context, ref, playbackState),  // Show list
),
```

### Three UI States:

1. **Loading State** (Lines 181-195)
```dart
Widget _buildLoadingState() {
  return const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        SizedBox(height: 16),
        Text('Loading tracks...'),
      ],
    ),
  );
}
```

2. **Empty State** (Lines 199-223)
```dart
Widget _buildNoTracksState(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Ionicons.musical_notes_outline,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No track listing available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
```

3. **Track List State** (Lines 226-265)
- Groups tracks by side (for vinyl)
- Shows side headers if multiple sides
- Each track shows: position, play icon, title, duration
- Click to play preview

---

## State Management Pattern

### In the Screen (coverflow_music_browser.dart)

```dart
// State variables
List<Track>? _currentTracks;  // Currently displayed tracks
bool _loadingTracks = false;  // Loading indicator

// Three states managed:
// 1. _loadingTracks = true, _currentTracks = null → Show spinner
// 2. _loadingTracks = false, _currentTracks = [] → Show empty state
// 3. _loadingTracks = false, _currentTracks = [Track...] → Show list

// Trigger logic
void _onControllerChanged() {
  if (_controller!.overlayVisible && !_loadingTracks && _currentTracks == null) {
    setState(() => _loadingTracks = true);
    Future.microtask(() => _loadTracksForCurrentItem());
  }
}
```

### Provider Injection

```dart
// From music_providers.dart (Lines 42-45)
final trackServiceProvider = Provider((ref) {
  final itemRepository = ref.watch(itemRepositoryProvider);
  return TrackService(itemRepository);
});

// Used in screen:
final trackService = ref.read(trackServiceProvider);
```

---

## Complete Data Flow Diagram

```
User taps center album cover
    ↓
CoverFlowController.overlayVisible = true
    ↓
_onControllerChanged() called
    ↓
Future.microtask(() => _loadTracksForCurrentItem())
    ↓
setState() { _loadingTracks = true }
    ↓
[UI rebuilds: shows spinner]
    ↓
_loadTracksForCurrentItem() executes
    ├─ Check item.tracks in memory
    │   └─ If found and has previews: return immediately
    │
    ├─ Call trackService.getTracksForItem(item, householdId)
    │
    └─ TrackService logic:
        ├─ Check item.tracks (Firestore cache)
        │   └─ If found but no previews: enrich → save → return
        │
        ├─ Check item.discogsId
        │   ├─ If found: fetch from Discogs API
        │   │   ├─ Enrich with iTunes previews
        │   │   ├─ Save to Firestore (updateItemTracks)
        │   │   └─ Return
        │   │
        │   └─ If not found: return []
        │
        └─ On error: return [] (graceful degradation)
    ↓
setState() { _currentTracks = tracks, _loadingTracks = false }
    ↓
[UI rebuilds: shows tracks or empty state]
    ↓
TrackOverlayPanel displays appropriately
```

---

## Key Takeaways

1. **Lazy Loading** - Triggered only when overlay becomes visible
2. **Cache-First** - Always check item.tracks before API calls
3. **Service Encapsulation** - All complex logic in TrackService
4. **Deferral Pattern** - Use Future.microtask() to prevent UI blocking
5. **Silent Failures** - Errors return empty list, not thrown
6. **Lightweight Persistence** - updateItemTracks() is simple and fast
7. **Enrichment** - iTunes preview URLs added automatically
8. **Three UI States** - Loading → Empty → Loaded