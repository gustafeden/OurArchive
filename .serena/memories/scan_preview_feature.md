# Scan Preview Feature

## Overview
Added a preview button to the scan-to-check screen that allows users to preview album tracklists and listen to song samples before deciding to add an album to their collection.

## What Was Implemented

### 1. Preview Button on Album Cards
**File:** `lib/ui/widgets/scanner/vinyl_selection_dialog.dart`

- Added `onPreview` callback parameter to `_VinylSelectionItem` widget
- Added a play circle icon button next to each album card
- Button appears for all albums in the selection dialog

**Location:** Lines 243, 398-405

### 2. VinylSelectionResult Class
**File:** `lib/ui/widgets/scanner/vinyl_selection_dialog.dart`

Created a new result class to handle two actions:
- `'add'` - User taps the album card to go directly to add screen
- `'preview'` - User taps the preview button to see tracks first

**Location:** Lines 11-20

### 3. Preview Dialog
**File:** `lib/ui/screens/scan_to_check_screen.dart`

Created `_showVinylPreviewDialog` method that displays:
- Album cover image
- Album title and artist
- Metadata (label, year, format, country)
- **TrackPreviewSection** widget for tracklist and audio playback
- "Close" and "Add to Collection" buttons

**Location:** Lines 667-827

### 4. Updated Navigation Flow
**File:** `lib/ui/screens/scan_to_check_screen.dart`

Modified `_showAllReleasesAndAdd` to handle both actions:
- If action is 'preview': Show preview dialog, then optionally navigate to add screen
- If action is 'add': Navigate directly to add screen (existing behavior)

**Location:** Lines 729-804

## User Flow

### Before (Old Flow)
1. Scan barcode → Find album not in collection
2. Select album from list
3. **Immediately** go to save screen

### After (New Flow)
1. Scan barcode → Find album not in collection
2. See list of albums with preview buttons
3. **Option A:** Tap album card → Go directly to save screen (same as before)
4. **Option B:** Tap preview button (▶️ icon) → See preview dialog
   - View full tracklist
   - Listen to 30-second previews of songs
   - Decide: "Add to Collection" or "Close"

## Technical Details

### Preview Dialog Features
- **Async track loading:** Tracks load asynchronously from Discogs API
- **Track enrichment:** Automatically fetches iTunes preview URLs for audio playback
- **StatefulBuilder:** Dialog updates when tracks finish loading
- **TrackPreviewSection widget:** Reuses existing track preview UI with play/pause controls
- **Temporary Item:** Creates a temporary Item object for track fetching (not saved to database)

### Preview Button Icon
- Icon: `Ionicons.play_circle_outline`
- Color: Primary theme color
- Tooltip: "Preview tracks"

### Dialog Actions
- **Close button:** Returns 'close' action, resets scan state for next scan
- **Add to Collection button:** Returns 'add' action, navigates to AddVinylScreen

## Benefits
1. **Better decision making:** Users can verify the album and hear samples before adding
2. **Reduced clutter:** Prevents adding unwanted albums by mistake
3. **Music discovery:** Users can explore tracklists and listen before committing
4. **Flexible workflow:** Maintains fast "add" option while providing detailed preview option

## Code Reuse
- Reuses existing `TrackPreviewSection` widget from track_preview_section.dart
- Follows same pattern as `_showVinylNotFoundDialog` for consistency
- Uses same track loading logic as other screens (CoverFlow, Item Details)

## Related Files
- `lib/ui/widgets/scanner/vinyl_selection_dialog.dart` - Dialog with album list and preview buttons (added VinylSelectionResult class)
- `lib/ui/screens/scan_to_check_screen.dart` - Main scan screen with preview dialog
- `lib/ui/screens/vinyl_scan_screen.dart` - Updated to handle VinylSelectionResult (extracts .vinyl property)
- `lib/ui/widgets/scanner/track_preview_section.dart` - Track list with audio preview
- `lib/data/services/track_service.dart` - Track fetching and enrichment

## Related Memories
- `itunes_preview_improvements` - How track previews work with iTunes API
- `quick_scan_navigation_analysis` - Navigation flow for scan screens
- `track_loading_code_examples` - Code patterns for loading tracks

## Testing Recommendations
1. Scan a barcode that returns multiple albums
2. Click preview button on different albums
3. Verify tracks load and display correctly
4. Test audio playback in preview dialog
5. Verify "Add to Collection" button works from preview
6. Test "Close" button resets scan state correctly
7. Test direct "Add" by tapping album card (existing behavior)
