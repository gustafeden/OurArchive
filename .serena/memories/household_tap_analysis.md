# Household Tap Functionality Analysis

## Current Implementation

### 1. Household Display Location
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/ui/screens/household_list_screen.dart`
**Widget Class:** `HouseholdListScreen` (ConsumerWidget)
**Widget Type:** Card with ListTile inside, no onTap/onLongPress handlers on the card itself

### 2. Current Behavior
The household card (lines 88-224) displays:
- ListTile with household avatar, name, member count, code (for owners)
- NO onTap or onLongPress handlers on the ListTile or Card
- Two explicit buttons for navigation:
  - "View Items" button (line 162) → navigates to ItemListScreen
  - "Organize" button (line 180) → navigates to ContainerScreen

**Current state:** Households are NOT clickable via tap - only the explicit buttons work.

### 3. Organize View (ContainerScreen)
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/ui/screens/container_screen.dart`
**Class:** `ContainerScreen` (ConsumerStatefulWidget)
**Purpose:** Hierarchical container organization view for managing rooms, shelves, boxes, etc.
**Navigation:** Called with `householdId` and `householdName` parameters (lines 180-190)

### 4. Household Model Structure
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/data/models/household.dart`

```dart
class Household {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, String> members;  // uid -> role ('owner', 'member', 'viewer', 'pending')
  final String code;
  final int schemaVersion;
}
```

**Editable fields:** Only `name` can be edited (other fields are metadata)

### 5. Edit Household Functionality
**Current Status:** NO edit functionality exists yet
- HouseholdService has no `updateHousehold()` method
- No edit household screen exists
- No edit dialog in household_list_screen.dart

### 6. HouseholdService Methods
**File:** `/Users/gustafeden/gustaf/OurArchive/our_archive/lib/data/services/household_service.dart`

Available methods:
- `createHousehold()` - creates new household
- `requestJoinByCode()` - join household by code
- `approveMember()` - owner approves pending members
- `removeMember()` - owner removes members
- `getUserHouseholds()` - stream of user's households
- `getPendingMembers()` - stream of pending approvals

MISSING: `updateHousehold()` or `updateHouseholdName()` method

## Implementation Plan Summary

To implement the requested functionality:

1. **Add onTap to ListTile** (line 92) → Navigate to ContainerScreen (Organize view)
2. **Add onLongPress to ListTile** → Show edit dialog (for owners only)
3. **Create updateHousehold() method in HouseholdService**
4. **Create edit dialog** to modify household name
5. **Update Firestore** with new household name
