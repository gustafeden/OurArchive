# Vinyl/Music Format Handling Analysis

## Overview
The OurArchive codebase handles music/vinyl items through a multi-step flow that involves barcode scanning, API lookup, and item creation. The format information comes from the Discogs API but is currently handled in a confusing way.

## Key Finding: Format Field Duplication Issue

There are TWO separate format-related fields being set:
1. **`format`** (List<String>) - Comes from Discogs API, represents technical format like "Vinyl", "CD", "Cassette" (from Discogs 'format' field)
2. **`musicFormat`** (String) - A custom dropdown field in the UI for user selection: 'vinyl', 'cd', 'cassette', 'digital', 'other'

### Current Behavior
In `add_vinyl_screen.dart` lines 131-138:
```dart
// Save the selected format
itemData['musicFormat'] = _selectedFormat;  // User-selected dropdown value

if (widget.vinylData != null) {
  itemData['styles'] = widget.vinylData!.styles;
  itemData['format'] = widget.vinylData!.format;  // From Discogs API
  itemData['country'] = widget.vinylData!.country;
}
```

This creates confusion:
- `musicFormat` is set by user selection from dropdown
- `format` is ONLY set if Discogs data is available (barcode/search lookup)
- If manually entering an item, only `musicFormat` is saved, not `format`

## Format Data Flow

### 1. Discogs API Response
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/services/discogs_service.dart`

The Discogs API returns data with a `format` field (array of strings):
- Search endpoints: `searchByBarcode()`, `searchByText()`
- Details endpoint: `getReleaseDetails()`

### 2. VinylMetadata Model
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/data/models/vinyl_metadata.dart`

Line 10: `final List<String>? format;`

Extracted from Discogs JSON (lines 56-58):
```dart
format: json['format'] != null
    ? List<String>.from(json['format'])
    : null,
```

Examples from Discogs:
- `["Vinyl", "Album"]`
- `["CD", "Album"]`
- `["Cassette"]`

### 3. VinylLookupService
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/services/vinyl_lookup_service.dart`

Three lookup methods:
- `lookupByBarcode(String barcode)` - Returns single VinylMetadata
- `searchByText(String query)` - Returns List<VinylMetadata>
- `getDetailedInfo(String releaseId)` - Returns single VinylMetadata with full details

### 4. VinylScanScreen
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/ui/screens/vinyl_scan_screen.dart`

Two modes:
1. **Camera mode** (VinylScanMode.camera):
   - Barcode scanning via mobile_scanner
   - Calls `VinylLookupService.lookupByBarcode()`
   - Shows preview dialog with vinyl data (does NOT display format)
   
2. **Text search mode** (VinylScanMode.textSearch):
   - Manual text input
   - Calls `VinylLookupService.searchByText()`
   - Shows search results list (does NOT display format)

Note: Neither preview nor search results display the `format` field!

### 5. AddVinylScreen
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/ui/screens/add_vinyl_screen.dart`

Pre-fill logic (lines 55-66):
- Populates from `widget.vinylData` if provided
- Sets title, artist, label, year, genre, catalogNumber
- Downloads cover image

Format handling (lines 42, 45, 206-224):
- Has dropdown list: `['vinyl', 'cd', 'cassette', 'digital', 'other']`
- Default value: `'vinyl'`
- Saves as `musicFormat` in itemData

Missing: Does NOT pre-select the format based on Discogs API data!

### 6. Item Model
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/data/models/item.dart`

Line 42: `final List<String>? format;`

Stored in Firestore as is. The model also has other vinyl-specific fields:
- artist, label, releaseYear, genre, styles, catalogNumber, country, discogsId

But does NOT have a `musicFormat` field!

## BarcodeScanScreen (for comparison)
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/ui/screens/barcode_scan_screen.dart`

Line 615 shows format is DISPLAYED in preview:
```dart
if (vinyl.format != null && vinyl.format!.isNotEmpty) 
  Text('Format: ${vinyl.format!.join(', ')}'),
```

This is used in the barcode scan screen for books/vinyls.

## Issues & Inconsistencies

1. **VinylScanScreen doesn't show format in previews** (lines 231-282, 284-335)
   - Preview dialogs only show: title, artist, label, year
   - Does NOT show format field despite having it from API

2. **No auto-population of format in AddVinylScreen**
   - Even though `widget.vinylData` contains format data, it's not used
   - Format dropdown always defaults to 'vinyl'
   - User must manually select if they want different format

3. **Two different format concepts**
   - API format from Discogs (List<String>): e.g., ["Vinyl", "Album"]
   - UI format selection (String): e.g., "vinyl", "cd", "cassette"
   - No mapping between them

4. **Manual entry has no format info**
   - When manually entering vinyl via AddVinylScreen without Discogs data
   - `widget.vinylData` is null
   - Only `musicFormat` gets saved, never `format` field

5. **BarcodeScanScreen shows format, VinylScanScreen doesn't**
   - Inconsistent UX between the two scan screens

## Data Availability

When barcode/search lookup succeeds:
- `VinylMetadata.format` contains: List<String> from Discogs
- In AddVinylScreen, this is available as `widget.vinylData!.format`

Currently, this API format data is stored in the Item's `format` field in Firestore.
But it's never displayed to the user during the add flow.
