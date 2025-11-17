# CoverFlow Track Loading and Saving Pattern

## Overview
This document details the complete flow of how CoverFlow loads and caches music tracks, which should be replicated in scanning screens.

## 1. CoverFlow Track Loading Flow

### Entry Point: coverflow_music_browser.dart

**Trigger Points:**
- Overlay visibility: Tracks are loaded ONLY when the track overlay panel becomes visible (on center album tap)
- Smart lazy loading: `_onControllerChanged()` detects overlay visibility and defers track loading

### Load Sequence:

```
_onControllerChanged() 
  ├─ Checks: if (_controller!.overlayVisible && !_loadingTracks && _currentTracks == null)
  ├─ Sets state: _loadingTracks = true
  ├─ Defers execution: Future.microtask(() => _loadTracksForCurrentItem())
  └─ Returns early (already called setState)

_loadTracksForCurrentItem()
  ├─ Step 1: Check if item.tracks already cached
  │   └─ if (item.tracks != null && item.tracks!.isNotEmpty)
  │       └─ Use cached tracks immediately
  │       └─ Return early
  │
  ├─ Step 2: Validate Discogs ID required
  │   └─ if (item.discogsId == null || item.discogsId!.isEmpty)
  │       └─ Return empty list (cannot fetch without ID)
  │
  ├─ Step 3: Fetch from TrackService
  │   └─ trackService.getTracksForItem(item, householdId)
  │
  └─ Step 4: Update UI state with results
      └─ setState() with _currentTracks and _loadingTracks = false
```

**Key Points:**
- Tracks are displayed via `TrackOverlayPanel` widget
- Loading state is managed via `_loadingTracks` and `_currentTracks` state variables
- Error handling is silent (returns empty list, UI shows "No track listing available")
- UI shows 3 states: loading spinner, track list, or empty state

---

## 2. TrackService Details (track_service.dart)

### getTracksForItem() - The Core Method

```dart
Future<List<Track>> getTracksForItem(Item item, String householdId) async {
  // CACHE STRATEGY 1: Use item's cached tracks if they have preview URLs
  if (item.tracks != null && item.tracks!.isNotEmpty) {
    // Check if tracks already have preview URLs
    final hasPreviewUrls = item.tracks!.any((t) => t.previewUrl != null);
    if (hasPreviewUrls) {
      return item.tracks!;  // Return immediately without fetching
    }

    // CACHE STRATEGY 2: Enrich existing tracks with previews
    try {
      final tracksWithPreviews = await enrichTracksWithPreviews(item.tracks!, item);
      if (tracksWithPreviews.isNotEmpty) {
        await cacheTracksToItem(householdId, item.id, tracksWithPreviews);
      }
      return tracksWithPreviews;
    } catch (e) {
      return item.tracks!;  // Fallback: return without previews
    }
  }

  // No tracks cached - fetch from Discogs if ID available
  if (item.discogsId == null || item.discogsId!.isEmpty) {
    return [];
  }

  try {
    // CACHE STRATEGY 3: Fetch new tracks from Discogs
    final tracks = await fetchTracksFromDiscogs(item.discogsId!);

    // Enrich with preview URLs from iTunes
    final tracksWithPreviews = await enrichTracksWithPreviews(tracks, item);

    // Cache the tracks back to Firestore
    if (tracksWithPreviews.isNotEmpty) {
      await cacheTracksToItem(householdId, item.id, tracksWithPreviews);
    }

    return tracksWithPreviews;
  } catch (e) {
    // Graceful degradation - return empty list
    print('Error fetching tracks for item ${item.id}: $e');
    return [];
  }
}
```

### Three-Level Caching Strategy:

1. **Firestore Cache (Persistent)**: `item.tracks` field in the Item document
   - Most recent and complete track data
   - Includes preview URLs enriched from iTunes
   - Loaded automatically when Item is fetched from Firestore

2. **In-Memory Cache (Session)**: `_currentTracks` in the screen widget
   - Tracks currently displayed in the overlay
   - Prevents redundant loads if user scrolls away and back

3. **Discogs API Cache**: Only checked if Firestore cache is empty
   - External source, used only when item has no cached tracks
   - Must have a Discogs ID for this to work

### Helper Methods:

**fetchTracksFromDiscogs(String discogsId)**
- Calls `DiscogsService.getReleaseDetails(discogsId)`
- Parses tracklist from API response
- Maps to Track model with position, title, duration, side (for vinyl)
- No preview URLs at this stage

**enrichTracksWithPreviews(List<Track> tracks, Item item)**
- Calls iTunes API to find matching tracks
- Uses album name and artist from Item
- Matches returned tracks with local tracks by title
- Returns enriched Track objects with previewUrl field populated
- On error: returns original tracks without previews

**cacheTracksToItem(String householdId, String itemId, List<Track> tracks)**
- Calls `itemRepository.updateItemTracks()`
- Does NOT throw on failure
- Critical for persistence between sessions

---

## 3. Item Repository Track Saving (item_repository.dart)

### updateItemTracks() Method - Lightweight Update

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

**Key Design Patterns:**

1. **No Version Check**: Unlike `updateItem()`, this method does NOT use transactions or version checks
   - Reason: Track data is enrichment only, not critical item data
   - Conflict resolution: Last write wins (acceptable for track metadata)
   - Performance: Simpler, faster update

2. **Silent Failure**: Catch block doesn't rethrow
   - Track caching failure shouldn't break the UI
   - User can still see tracks in current session even if save fails
   - Retry on next session when tracks are re-fetched

3. **Uses Firestore Update**: Not set(), preserving other item fields
   - Only updates tracks and lastModified timestamp
   - Lightweight operation

4. **Serialization**: `tracks.map((t) => t.toJson()).toList()`
   - Each Track must have a toJson() method
   - Stores complete track metadata including previews

---

## 4. Firestore Data Structure

### Item Document - Tracks Field

```
households/{householdId}/items/{itemId}
{
  id: "item-uuid",
  type: "vinyl",
  title: "Abbey Road",
  artist: "The Beatles",
  discogsId: "12345",
  
  // This is what's saved by updateItemTracks()
  tracks: [
    {
      position: "A1",
      title: "Come Together",
      duration: "4:15",
      side: "A",
      artist: null,
      previewUrl: "https://audio.itunes.apple.com/..."
    },
    {
      position: "A2",
      title: "Something",
      duration: "3:02",
      side: "A",
      artist: null,
      previewUrl: "https://audio.itunes.apple.com/..."
    },
    // ... more tracks
  ],
  
  // Metadata
  createdAt: Timestamp,
  lastModified: Timestamp,
  version: 1,
  syncStatus: "synced"
}
```

---

## 5. Complete Flow Diagram

```
CoverFlow Screen Opens
  │
  ├─ Load music items (vinyl only)
  ├─ Display covers in carousel
  │
User taps center album (to show overlay)
  │
  └─→ _onControllerChanged() detects overlayVisible = true
      │
      └─→ Future.microtask() queues _loadTracksForCurrentItem()
          │
          ├─→ Check: item.tracks != null && !empty?
          │   │
          │   YES → Use immediately
          │   │   └─→ Check: tracks have preview URLs?
          │   │       │
          │   │       YES → Return cached tracks
          │   │       │
          │   │       NO → Enrich with iTunes previews
          │   │           └─→ cacheTracksToItem() in Firestore
          │   │           └─→ Return enriched tracks
          │   │
          │   NO → Check: item.discogsId?
          │       │
          │       YES → Fetch from Discogs API
          │       │   ├─→ Parse tracklist
          │       │   ├─→ Enrich with iTunes previews
          │       │   └─→ cacheTracksToItem() in Firestore
          │       │
          │       NO → Return empty list
          │
          └─→ setState() with tracks
              │
              └─→ TrackOverlayPanel displays:
                  ├─ If loading → Loading spinner
                  ├─ If empty → "No track listing available"
                  └─ If tracks → List grouped by side (vinyl)
                                └─ Click track → Play preview
```

---

## 6. Pattern to Replicate in Scanning Screens

### What to Copy:

1. **Lazy Loading Trigger**
   ```dart
   // Load tracks only when user needs them (e.g., on Add screen, in preview)
   if (shouldLoadTracks && !isLoadingTracks && currentTracks == null) {
     setState(() => isLoadingTracks = true);
     Future.microtask(() => _loadTracks());
   }
   ```

2. **Three-Level Cache Check**
   ```dart
   // 1. Check Firestore cache (item.tracks)
   if (item.tracks != null && item.tracks!.isNotEmpty) {
     return item.tracks!;
   }
   
   // 2. Check Discogs if no cache
   if (item.discogsId != null) {
     // 3. Enrich from iTunes
     // 4. Save back to Firestore
   }
   ```

3. **Service-Based Loading**
   - Always use `TrackService.getTracksForItem(item, householdId)`
   - Don't duplicate track logic in screens
   - Service handles all cache strategies internally

4. **Safe Error Handling**
   - Return empty list, not null
   - Don't throw exceptions from track loading
   - Show appropriate UI states (loading, empty, list)

5. **Firestore Persistence**
   - Use `itemRepository.updateItemTracks()` to save
   - Don't worry about failures (silent handling)
   - Let tracks be fetched again next session if needed

### Example Pattern for Scanning Screens:

```dart
class VinylScanScreen extends ConsumerStatefulWidget {
  // ...
  
  _VinylScanScreenState extends ConsumerState {
    List<Track>? _tracks;
    bool _loadingTracks = false;
    
    // When showing item preview after successful scan
    void _showItemPreview(Item item) async {
      // Optionally load tracks here
      await _loadTracksForItem(item);
      
      // Show preview dialog with tracks
      showDialog(...);
    }
    
    Future<void> _loadTracksForItem(Item item) async {
      if (_loadingTracks || _tracks != null) return;
      
      setState(() => _loadingTracks = true);
      
      try {
        final trackService = ref.read(trackServiceProvider);
        final tracks = await trackService.getTracksForItem(item, householdId);
        
        if (mounted) {
          setState(() {
            _tracks = tracks;
            _loadingTracks = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loadingTracks = false);
        }
      }
    }
  }
}
```

---

## 7. Key Implementation Details

### Track Model (Must have):
- `toJson()` method for Firestore serialization
- `position`, `title`, `duration`, `side` (for vinyl)
- `previewUrl` (nullable, populated by iTunes enrichment)
- `artist` (nullable, for compilations)

### Item Model (Must have):
- `tracks` field: `List<Track>?`
- `discogsId` field: `String?`
- Proper deserialization from Firestore Document

### Service Providers:
```dart
final trackServiceProvider = Provider((ref) {
  final itemRepository = ref.watch(itemRepositoryProvider);
  return TrackService(itemRepository);
});
```

### UI States to Support:
1. **Loading**: Show spinner with "Loading tracks..."
2. **Empty**: Show icon with "No track listing available"
3. **Loaded**: Show track list, grouped by side if vinyl

---

## Summary

The CoverFlow pattern achieves:
- **Efficiency**: Caches tracks persistently in Firestore
- **Performance**: Lazy loads only when needed (overlay tap)
- **Resilience**: Gracefully handles missing Discogs IDs or API failures
- **Enrichment**: Automatically fetches iTunes preview URLs
- **Simplicity**: Service encapsulates all complexity
- **Reusability**: Single `TrackService` used across the app

To replicate in scanning screens: Use the same `TrackService` with identical cache strategies, loading states, and error handling.