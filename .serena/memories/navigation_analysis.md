# Navigation Issue Analysis

## Problem
When user navigates: Container A → Container B → Add Item → ... → AddBookScreen, the app uses `Navigator.popUntil(context, (route) => route.isFirst)` which goes back to the HOME screen, not the originating container (Container B).

## Current Navigation Pattern

### Routes without Settings.name
- ItemListScreen: pushed without route name (MaterialPageRoute)
- ContainerScreen: pushed without route name (MaterialPageRoute)
- ItemTypeSelectionScreen: pushed without route name (MaterialPageRoute)
- AddBookFlowScreen: pushed without route name (MaterialPageRoute)
- AddBookScreen: pushed without route name (MaterialPageRoute)

### Key Navigation Code

1. **ItemListScreen FAB** (line 306-314):
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ItemTypeSelectionScreen(
      householdId: widget.household.id,
    ),
  ),
);
```

2. **ContainerScreen FAB** (line 1602-1614):
```dart
void _navigateToAddItem(BuildContext context, WidgetRef ref) async {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ItemTypeSelectionScreen(
        householdId: widget.householdId,
        preSelectedContainerId: widget.parentContainerId,
      ),
    ),
  );
}
```

3. **AddBookScreen Save** (line 200-201):
```dart
// Pop all screens and return to the main list/container screen
Navigator.popUntil(context, (route) => route.isFirst);
```

## Key Insight
ContainerScreen already passes `preSelectedContainerId` through the add flow screens, but the problem is:
- ItemListScreen does NOT pass any parent information
- When returning from add flow, both ItemListScreen and ContainerScreen use `Navigator.popUntil(context, (route) => route.isFirst)` which goes to the HOME screen

## Solutions to Consider

### Option 1: Use Route Settings Names
- Assign unique route names to ItemListScreen and ContainerScreen
- Pop back to a specific route by name instead of to first route
- Cleanest approach for named route navigation

### Option 2: Track Parent Screen Context
- Pass parent screen identifier through the entire add flow
- Modify add screens to pop to specific parent instead of popUntil isFirst
- Requires tracking whether parent is ItemListScreen or ContainerScreen

### Option 3: Use WillPopScope/PopScope with Return Values
- Have add screens return completion status
- Parent screens listen for return value and handle cleanup
- More reactive/responsive approach

### Option 4: Named Routes with Go Router
- Replace MaterialPageRoute with named routes
- Use Go Router for better route management
- More robust for complex navigation flows

## Current Parameters Already Used
- `preSelectedContainerId`: Passed from ContainerScreen through add flow
- Could extend this to include parent screen type
