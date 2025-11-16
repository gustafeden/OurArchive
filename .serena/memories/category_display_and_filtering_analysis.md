# Category Display and Filtering Analysis

## Summary
The OurArchive app uses a flat item type system where "vinyl" is treated as a top-level category. The category display system has hardcoded category tabs, icon mappings, and filtering logic spread across multiple locations. All category information is defined in item_list_screen.dart.

---

## 1. Where "Vinyl" Category Label is Defined and Displayed

### Primary Location: ItemListScreen
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/ui/screens/item_list_screen.dart`

#### Category Tabs Display (Lines 503-562)
The `_buildCategoryTabs()` method displays horizontal category tabs at the top of the list view:
- **Label Definition:** Line 533 - `label: 'Vinyl'`
- **Type Value:** Line 535 - mapped to `selectedType == 'vinyl'`
- **Count:** Line 508 - `final vinylCount = allItems.where((i) => i.type == 'vinyl').length;`

```dart
_CategoryTab(
  label: 'Vinyl',
  count: vinylCount,
  isSelected: selectedType == 'vinyl',
  onTap: () => ref.read(selectedTypeProvider.notifier).state = 'vinyl',
),
```

#### Secondary Display Locations in ItemListScreen:
1. **Type Label Generation** (Line 396, 451): `typeLabel = type[0].toUpperCase() + type.substring(1);`
   - This auto-capitalizes the type name ("vinyl" → "Vinyl")
   - Used in grouped list view and browse view section headers

2. **Type Filtering Dialog** (Line 691): Lists all available types including 'vinyl'

3. **Grouped List View** (Lines 372-423): When "All" is selected in list mode
   - Uses categoryOrder array (Line 375) with 'vinyl' as second item
   - Groups items by type and displays section headers

4. **Browse View** (Lines 425-474): Collapsible category sections
   - Uses same categoryOrder array
   - Shows expandable/collapsible sections by category

### Icon Mapping (Line 476-500)
```dart
IconData _getIconForType(String type) {
  switch (type) {
    case 'vinyl':
      return Icons.album;
    // ...
  }
}
```

---

## 2. How Categories Are Organized and Shown in the UI

### Two View Modes:
1. **List Mode** (Default):
   - Horizontal category tabs at top for quick filtering
   - When "All" selected: grouped by type with section headers
   - When specific type selected: flat list of items

2. **Browse Mode**:
   - No category tabs
   - Collapsible category sections with expand/collapse arrows
   - Sections expand to show items within

### Category Tab Structure (Lines 503-562):
- **Featured Categories** (as tabs): All, Books, Vinyl, Games, Tools
- **Other Categories** (in dialog): general, pantry, camera, electronics, clothing, kitchen, outdoor

The "Vinyl" label appears ONLY in the featured tabs.
Other types appear in the "Other" dialog when clicked.

### Category Ordering
**Primary Order (Lines 375, 428):** 
```dart
final categoryOrder = ['book', 'vinyl', 'game', 'tool', 'pantry', 'camera', 'electronics', 'clothing', 'kitchen', 'outdoor', 'general'];
```

This array determines:
- Order of grouped sections in list view (when "All" selected)
- Order of collapsible sections in browse view

---

## 3. How Items are Filtered by Type

### Data Flow:
1. **User Selection**: Click category tab → updates `selectedTypeProvider` state
2. **Filter Logic** (providers.dart, Line 79):
   ```dart
   if (selectedType != null && item.type != selectedType) {
     return false;
   }
   ```
3. **Filtered Items**: `filteredItemsProvider` returns filtered list based on selection

### Providers Involved:
- `selectedTypeProvider` (StateProvider<String?>): Tracks currently selected type
- `filteredItemsProvider` (Provider<List<Item>>): Applies all filters including type

### Filter Buttons (Lines 595-676):
- Type Filter Button → Opens dialog with all types
- Container Filter Button
- Tag Filter Button

**Type Filter Dialog** (Lines 690-719):
Shows all 11 types:
```dart
final types = ['general', 'tool', 'pantry', 'camera', 'book', 'vinyl', 'game', 'electronics', 'clothing', 'kitchen', 'outdoor'];
```

---

## 4. Data Model - Valid Type Values

**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/data/models/item.dart` (Line 8)

```dart
final String type; // 'pantry', 'tool', 'camera', etc.
```

### Valid Type Values (from item_list_screen.dart):
1. `'book'` - Books
2. `'vinyl'` - Vinyl records (and other music formats)
3. `'game'` - Video games
4. `'tool'` - Tools
5. `'pantry'` - Pantry items
6. `'camera'` - Cameras
7. `'electronics'` - Electronics
8. `'clothing'` - Clothing
9. `'kitchen'` - Kitchen items
10. `'outdoor'` - Outdoor items
11. `'general'` - General items (catch-all)

### Vinyl-Specific Fields (Item Model):
- `artist` (String)
- `label` (String)
- `releaseYear` (String)
- `genre` (String)
- `styles` (List<String>)
- `catalogNumber` (String)
- `format` (List<String>) - From Discogs API (e.g., ["Vinyl", "Album"])
- `country` (String)
- `discogsId` (String)

**Important Note:** The `format` field stores the Discogs API format (e.g., ["Vinyl", "CD"]), but this is separate from the item type which is always `'vinyl'`.

---

## 5. How Layout Handles Category Grouping in Different View Modes

### List Mode:
**All Items Selected**:
- `_buildGroupedItemList()` (Lines 372-423)
- Groups items by `item.type`
- Displays sections with:
  - Icon + Type Label + Count
  - Divider between sections
  - Flat item list under each section

**Specific Type Selected**:
- Simple `ListView.builder()` (Lines 259-265)
- No grouping, just flat list of filtered items

### Browse Mode:
- `_buildBrowseView()` (Lines 425-474)
- Always groups by type
- Uses `_CollapsibleCategorySection` widget (Lines 1022-1080)
- Each section has:
  - Header with icon, label, count, expand/collapse arrow
  - Expandable content showing items (if expanded)
  - Divider

**Expanded State Management:**
- `expandedCategoriesProvider` (StateProvider<Set<String>>)
- Tracks which category sections are expanded
- Persists across view navigation

---

## Key Hardcoded Locations

1. **Category Tab Labels** (Line 525-559):
   - "Books" → type 'book'
   - "Vinyl" → type 'vinyl'
   - "Games" → type 'game'
   - "Tools" → type 'tool'
   - "Other" → all remaining types

2. **Category Order** (Lines 375, 428):
   - Hardcoded array defining sort order

3. **Icon Mapping** (Lines 476-500):
   - Switch statement mapping type to MaterialIcon

4. **Type Filter Lists**:
   - Line 565: Other types dialog: `['general', 'pantry', 'camera', 'electronics', 'clothing', 'kitchen', 'outdoor']`
   - Line 691: Full types list: `['general', 'tool', 'pantry', 'camera', 'book', 'vinyl', 'game', 'electronics', 'clothing', 'kitchen', 'outdoor']`
   - Line 511: Featured item check: `['book', 'vinyl', 'game', 'tool']`

---

## Current Item Creation Flow for Vinyl

**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/ui/screens/item_type_selection_screen.dart`

1. User clicks "Music" card (Line 123-138)
2. Navigates to AddVinylFlowScreen
3. User chooses: Scan, Search, or Manual Entry
4. All paths create item with `type: 'vinyl'` in Firestore
5. No sub-type/format selection at item creation time

**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/ui/screens/add_vinyl_screen.dart`

- Creates all music items with `type: 'vinyl'`
- Optional `musicFormat` field exists in some flows but is NOT stored in Item model
- The Discogs API `format` field IS stored but never displayed to user

---

## Filtering Consistency

### Search & Filter Integration (providers.dart, Lines 66-97):
Multiple filters can be applied simultaneously:
- `searchQuery` - text search in searchText field
- `selectedType` - exact match on type
- `selectedContainer` - match on containerId
- `selectedTag` - match on tags array
- `archived` status - filters out archived items

All are combined with AND logic (all must be true).

---

## Pattern for Category Display

All category/type display follows this pattern:

1. **Hardcoded string literals** for type values in screens
2. **Type-aware UI generation** (switch statements on type)
3. **Centralized category order** in two places (should be one)
4. **Capitalization** done automatically with `type[0].toUpperCase() + type.substring(1)`
5. **Icon mapping** via switch statement

---

## Implications for Music Sub-Categories

Currently:
- All music items have `type: 'vinyl'` regardless of actual format
- The `format` field from Discogs (["Vinyl", "CD", etc.]) is stored but never displayed
- UI shows "Vinyl" tab/label for all music items
- No way to filter by specific format (CD vs Vinyl vs Cassette) in UI

To implement hierarchical filtering (CD/Vinyl/Cassette under Music):
- Option 1: Change item.type values (e.g., type: 'music.vinyl', 'music.cd')
- Option 2: Add a separate musicFormat field to Item model and use in filtering
- Option 3: Leverage existing format field and create sub-filters
- Current pattern does NOT support hierarchical categories

---

