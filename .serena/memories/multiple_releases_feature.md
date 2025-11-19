# Multiple Releases Selection Feature

## Overview

Implemented comprehensive support for handling multiple Discogs releases with the same barcode, allowing users to view, select, and switch between different releases of the same album.

## Problem Statement

Previously, when scanning a music barcode that matched multiple Discogs releases:
- Only the first result was used automatically
- Users couldn't see or select alternative releases
- No indication if they already owned a different release with the same barcode
- No way to switch releases after entering the Add Music screen

## Solution Implemented

### 1. Enhanced Selection Dialog with Pagination

**File**: `lib/ui/widgets/scanner/vinyl_selection_dialog.dart`

A sophisticated selection dialog that shows all available releases with:
- **Visual indicators for owned items**:
  - Green background tint (`Colors.green.withValues(alpha: 0.08)`)
  - "Owned (qty: X)" badge with green background
  - Green checkmark icon (Ionicons.checkmark_circle)
  - Container location displayed below metadata
- **Smart sorting**: Owned releases appear at the top of the list
- **Pagination support**: "Load More Results (X remaining)" button
- **Rich metadata display**: Format, country, year, label, catalog number
- **Cover art thumbnails** with fallback icons

### 2. Pagination Infrastructure

**Files Created**:
- `lib/data/models/discogs_search_result.dart`

**Models**:
```dart
class PaginationInfo {
  final int currentPage;
  final int totalPages;
  final int perPage;
  final int totalItems;
  bool get hasMore => currentPage < totalPages;
}

class DiscogsSearchResult {
  final List<VinylMetadata> results;
  final PaginationInfo pagination;
}
```

**Configuration**: 
- Default page size: 5 results per page
- Fetches additional pages on demand
- Appends results to existing list and re-sorts

### 3. Repository Enhancements

**File**: `lib/data/repositories/item_repository.dart`

Added methods to find ALL matching items (not just first match):

```dart
Future<List<Item>> findAllItemsByBarcode(String householdId, String barcode)
Future<List<Item>> findAllItemsByDiscogsId(String householdId, String discogsId)
```

**Implementation**: In-memory search through cached items (no Firestore indexes required)

### 4. Service Layer Updates

**File**: `lib/services/discogs_service.dart`

Added pagination support while maintaining backward compatibility:

```dart
static Future<Map<String, dynamic>> searchByBarcodeWithPagination(
  String barcode, {
  int page = 1,
  int perPage = 5,
}) async {
  final url = "$_base/database/search?barcode=$barcode&type=release&per_page=$perPage&page=$page";
  return {
    'results': data["results"] ?? [],
    'pagination': data["pagination"] ?? {},
  };
}
```

**File**: `lib/services/vinyl_lookup_service.dart`

Wrapper that converts Discogs responses to app models and preserves barcode:

```dart
static Future<DiscogsSearchResult> lookupByBarcodeWithPagination(
  String barcode, {
  int page = 1,
  int perPage = 5,
})
```

### 5. Scanning Flow Updates

**File**: `lib/ui/screens/vinyl_scan_screen.dart`

Updated to:
- Fetch ALL owned items with barcode in parallel with API search
- Always show selection dialog (even for single result) to display owned status
- Check if the SPECIFIC selected release is owned (by discogsId)
- Load tracks in preview dialog while user reviews metadata
- Pass pre-loaded tracks to Add screen

**Key Pattern**:
```dart
final results = await Future.wait([
  VinylLookupService.lookupByBarcodeWithPagination(barcode),
  itemRepository.findAllItemsByBarcode(householdId, barcode),
]);

final searchResult = results[0] as DiscogsSearchResult;
final ownedItems = results[1] as List<Item>;

// Always show selection dialog
final vinylMetadata = await showVinylSelectionDialog(
  barcode: barcode,
  initialResults: searchResult.results,
  initialPagination: searchResult.pagination,
  ownedItems: ownedItems,
  householdId: householdId,
);

// Check if THIS specific release is owned
final ownedItem = ownedItems.firstWhere(
  (item) => item?.discogsId == vinylMetadata.discogsId,
  orElse: () => null,
);
```

### 6. "Check If We Have It" Flow

**File**: `lib/ui/screens/scan_to_check_screen.dart`

Added methods:
- `_showMultipleVersionsFoundDialog()`: Shows "You Own X Version(s)!" with list of owned items
- `_showAllReleasesAndAdd()`: Opens selection dialog allowing user to add different release

**Flow**:
1. Scan barcode
2. Fetch all owned items AND all available releases in parallel
3. If owned items found:
   - Show "You Own X Version(s)!" dialog
   - List all owned versions with metadata
   - Offer "See All Releases" to view and add different releases
4. If not owned:
   - Show selection dialog to choose which release to add

### 7. "Select Different Release" on Add Screen

**File**: `lib/ui/screens/add_vinyl_screen.dart`

Added button in AppBar (lines 302-307):
```dart
if (widget.vinylData?.barcode != null)
  TextButton.icon(
    onPressed: _selectDifferentRelease,
    icon: const Icon(Ionicons.swap_horizontal_outline),
    label: const Text('Different Release'),
  ),
```

Added method `_selectDifferentRelease()` (lines 207-294) that:
- Fetches all releases for current barcode
- Shows enhanced selection dialog
- Updates metadata fields when different release selected
- **Preserves user inputs**: container selection, notes, custom edits
- Downloads new cover art
- Updates format field based on new release

## Architecture Decisions

### 1. Parallel Data Fetching
All owned item searches run in parallel with API calls using `Future.wait()` to minimize latency.

### 2. In-Memory Search
Finding owned items is done in-memory rather than Firestore queries to avoid requiring indexes and support complex queries (multiple barcodes, multiple discogsIds).

### 3. Stateful Dialog with Pagination
The selection dialog maintains its own state for:
- Loading more results
- Caching container names for location display
- Re-sorting list when new results added

### 4. Identification Strategy
- **Barcode**: Used for initial search (UPC/EAN from physical media)
- **discogsId**: Used for precise duplicate detection (different releases can share barcodes)
- Both are stored on items for robust matching

### 5. Backward Compatibility
Old methods like `lookupByBarcode()` still work by calling new paginated versions with default parameters.

## User Flows

### Flow 1: Scanning with Multiple Results
1. User scans barcode
2. Selection dialog shows all releases (5 at a time)
3. Owned releases appear first with green indicators
4. User can "Load More" to see additional releases
5. User selects desired release
6. Preview dialog shows with track loading
7. User proceeds to Add screen

### Flow 2: Checking Owned Items
1. User scans barcode in "Check if we have it" mode
2. System finds 2 owned releases with that barcode
3. Dialog shows "You Own 2 Versions!" with list
4. Each shows title, artist, format, container location
5. User can "See All Releases" to add different version
6. Selection dialog shows all releases with owned ones highlighted

### Flow 3: Switching Release on Add Screen
1. User is on Add Music screen (from scan or search)
2. User taps "Different Release" button in AppBar
3. Selection dialog shows all releases for that barcode
4. User selects alternative release
5. Metadata fields update (title, artist, label, year, format)
6. Cover art downloads
7. User's container selection and notes are preserved
8. User can continue editing or save

## Possible Improvements

### Short-term Enhancements

1. **Cache Loaded Pages**
   - Currently re-fetches all pages when reopening dialog
   - Could cache DiscogsSearchResult and resume from last state
   - Would improve UX when user backs out and returns

2. **Infinite Scroll Instead of "Load More"**
   - Replace button with automatic loading when scrolling to bottom
   - More modern UX pattern
   - Would require ListView.builder with scroll controller

3. **Search Within Results**
   - Add text field to filter displayed releases
   - Useful when many releases exist (some albums have 50+ versions)
   - Could filter by format, country, or year

4. **Format Icons**
   - Replace text format labels with icons (vinyl record, CD, cassette symbols)
   - More visual and space-efficient
   - Could use custom icon font or SVG assets

5. **Release Notes Preview**
   - Show additional details from Discogs (pressing notes, remaster info)
   - Would help users distinguish between similar releases
   - Could add expandable detail section or bottom sheet

### Medium-term Improvements

6. **Favorite/Preferred Releases**
   - Allow users to mark preferred version when multiple owned
   - Could affect sorting (show preferred first)
   - Store preference flag on Item model

7. **Batch Switching**
   - If user owns multiple copies with wrong release selected
   - Provide way to switch all at once
   - "I meant to add the CD version, not vinyl, for all 10 items"

8. **Release Comparison View**
   - Side-by-side comparison of two releases
   - Highlight differences (country, year, format, label)
   - Help users make informed decision

9. **Smart Release Suggestion**
   - Analyze user's collection (mostly CDs? mostly vinyl?)
   - Auto-select most likely format when multiple options
   - Could use ML or simple heuristics

10. **Offline Support**
    - Cache recent Discogs search results
    - Allow selection from cache when offline
    - Sync changes when connection restored

### Long-term Enhancements

11. **Discogs Collection Sync**
    - Import user's Discogs collection
    - Auto-match owned releases by discogsId
    - Two-way sync for collection management

12. **Release Version History**
    - Track when user switched releases
    - Allow rollback if mistake
    - Could be part of general item history/audit log

13. **Barcode Variants Database**
    - Some releases have multiple barcodes
    - Build local database of barcode->discogsId mappings
    - Could reduce API calls and improve accuracy

14. **Community Release Recommendations**
    - Show which release is most popular among app users
    - "Most users with this barcode chose the 2009 remaster"
    - Would require anonymous telemetry

15. **Advanced Duplicate Detection**
    - Beyond just barcode and discogsId
    - Fuzzy matching on title + artist + year
    - Could catch releases added via text search vs barcode

## Testing Checklist

- [ ] Scan barcode with single result → Selection dialog shows with owned indicator if applicable
- [ ] Scan barcode with multiple results → All results shown, pagination works
- [ ] Load More button → Fetches next page correctly, re-sorts owned to top
- [ ] Own multiple releases with same barcode → Both shown with green indicators
- [ ] Container location display → Shows correct container name for owned items
- [ ] Select Different Release button → Only shows when item has barcode
- [ ] Switch release on Add screen → Metadata updates, container/notes preserved
- [ ] Check mode with owned items → Shows count and list correctly
- [ ] See All Releases → Opens selection dialog with owned highlighted
- [ ] Edge case: barcode with 50+ releases → Pagination handles large result sets

## Performance Considerations

### Current Implementation
- Parallel fetching reduces total wait time
- In-memory search is fast for typical collection sizes (<10,000 items)
- Image loading with fallback prevents UI blocking
- Stateful builder updates only dialog content, not entire screen

### Potential Bottlenecks
- In-memory search could slow with very large collections (>50,000 items)
- Loading many high-res cover images could consume memory
- Multiple pagination requests if user loads many pages

### Mitigation Strategies
- Consider Firestore composite indexes if collection size grows
- Implement image caching and size optimization
- Add virtual scrolling for very long lists
- Implement debouncing on Load More button

## Related Files

### Core Feature Files
- `lib/ui/widgets/scanner/vinyl_selection_dialog.dart` - Main selection UI
- `lib/data/models/discogs_search_result.dart` - Pagination models
- `lib/services/vinyl_lookup_service.dart` - API wrapper with pagination
- `lib/services/discogs_service.dart` - Discogs API client
- `lib/data/repositories/item_repository.dart` - Item storage and retrieval

### Integration Points
- `lib/ui/screens/vinyl_scan_screen.dart` - Barcode scanning flow
- `lib/ui/screens/scan_to_check_screen.dart` - Check if owned flow
- `lib/ui/screens/add_vinyl_screen.dart` - Add/edit screen with release switching

### Supporting Components
- `lib/ui/widgets/common/network_image_with_fallback.dart` - Cover art display
- `lib/data/models/vinyl_metadata.dart` - Release metadata model
- `lib/data/models/item.dart` - Stored item model

## Code Style Notes

- Used conditional rendering (`if (condition) widget`) for cleaner code
- Parallel async operations with `Future.wait()` for performance
- Stateful dialogs maintain their own loading/pagination state
- Descriptive method names that explain intent
- Comments explain "why" not "what" for complex logic
- Preserved backward compatibility with wrapper methods

## Dependencies

- `ionicons` - Icon library for UI elements
- `flutter_riverpod` - State management for providers
- `http` - Discogs API communication
- No new dependencies added for this feature
