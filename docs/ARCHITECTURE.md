# OurArchive Architecture

**Last Updated:** 2025-11-17

## Overview

OurArchive is a Flutter-based household inventory management application built with a clean architecture approach. The application uses Firebase for backend services and follows Flutter best practices with Riverpod for state management.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│  (Screens, Widgets, State Management with Riverpod)         │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                      Services Layer                          │
│  (Business Logic, API Integrations, Local Operations)       │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                   Repositories Layer                         │
│  (Data Access, Firebase Abstraction, Sync Queue)            │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                    Firebase Backend                          │
│  (Auth, Firestore, Storage, Security Rules)                 │
└─────────────────────────────────────────────────────────────┘
```

## Widget Library

One of the key architectural improvements has been the creation of a comprehensive reusable widget library organized under `lib/ui/widgets/`. This library reduces code duplication and ensures UI consistency across the application.

### Common Widgets (`lib/ui/widgets/common/`)

General-purpose UI components used throughout the application:

#### PhotoPickerWidget
- **Purpose:** Unified image picker interface
- **Features:** Camera capture, gallery selection, photo removal
- **Usage:** Item creation screens, container setup
- **File:** `photo_picker_widget.dart`

#### LoadingButton
- **Purpose:** Button with async operation loading state
- **Features:** Disabled during loading, spinner indicator, customizable icon
- **Usage:** AppBar actions, form submissions
- **File:** `loading_button.dart`

#### ItemCardWidget
- **Purpose:** Standardized item display card
- **Features:**
  - Async thumbnail loading with fallback icons
  - Type-specific subtitles (book authors, vinyl artists, game platforms)
  - Optional edit mode (move/delete buttons)
  - Optional sync status indicator
  - Navigation to detail screen
- **Usage:** Container view, item list screen
- **File:** `item_card_widget.dart`

#### CategoryTab
- **Purpose:** Filter tab with label and count badge
- **Features:** Active state styling, item count display
- **Usage:** Category filtering in list views
- **File:** `category_tab.dart`

#### CategoryTabsBuilder
- **Purpose:** Category/type filter tabs with item counts
- **Modes:** Static (predefined) and Dynamic (from provider)
- **Features:**
  - Calculates item counts per category
  - "Other types" overflow handling with dialog
  - Custom tap handlers for special categories
- **Usage:** Container screen, item list screen
- **File:** `category_tabs_builder.dart`

#### EmptyStateWidget
- **Purpose:** Standardized empty state display
- **Features:** Icon, title, subtitle with consistent styling
- **Usage:** Empty lists, no search results, empty containers
- **File:** `empty_state_widget.dart`

#### NetworkImageWithFallback
- **Purpose:** Network image with graceful error handling
- **Features:** Loading state, error fallback to icon, configurable size
- **Usage:** Scanner preview dialogs, cover art display
- **File:** `network_image_with_fallback.dart`

#### DuplicateItemDialog
- **Purpose:** Reusable duplicate detection dialog
- **Modes:** Simple (text-only) and Elaborate (with images)
- **Features:** Async container name fetching, action handling
- **Usage:** Scanner screens when duplicate items detected
- **File:** `duplicate_item_dialog.dart`
- **Helper:** `showDuplicateItemDialog()` function for easy invocation

#### SearchResultsView
- **Purpose:** Generic text search UI with results list
- **Features:**
  - Generic type parameter for different result types
  - Parameterized result builder for custom list items
  - Integrated loading and empty states
- **Usage:** Book/vinyl scanner text search
- **File:** `search_results_view.dart`

### Form Widgets (`lib/ui/widgets/form/`)

Specialized form field components:

#### ContainerSelectorField
- **Purpose:** Dropdown for container selection
- **Features:** AsyncValue handling, optional/required modes, custom labels
- **Usage:** All item creation/edit screens
- **File:** `container_selector_field.dart`

#### YearField
- **Purpose:** Standardized 4-digit year input
- **Features:** Numeric keyboard, validation, optional state
- **Usage:** Book, vinyl, and game entry forms
- **File:** `year_field.dart`

#### NotesField
- **Purpose:** Multiline text field for notes/descriptions
- **Features:** Auto-expand, configurable label, optional state
- **Usage:** Item creation/edit forms
- **File:** `notes_field.dart`

## Utilities

### TextSearchHelper
- **Purpose:** Standardized text search with error handling
- **Features:** Input validation, loading state, error handling, empty results
- **Pattern:** Reusable across scanner screens for API text search
- **File:** `lib/utils/text_search_helper.dart`

## State Management

The application uses **Riverpod** for state management:

- **Providers:** Singleton services and repositories
- **AsyncValue:** Handling async data loading states
- **ConsumerWidget:** Reactive UI updates
- **StateNotifier:** Complex state management for features like sync queue

### Key Providers
- `authRepositoryProvider` - Authentication state
- `householdRepositoryProvider` - Household data access
- `containerRepositoryProvider` - Container data access
- `itemRepositoryProvider` - Item data access
- `syncQueueProvider` - Offline sync queue management

## Data Models

### Core Entities
- **User:** Authentication and profile information
- **Household:** Shared inventory space with members
- **Container:** Storage location for items
- **Item:** Individual inventory item with type-specific fields

### Type-Specific Models
- **Book:** ISBN, authors, publisher, year
- **Vinyl:** Barcode, artist, label, format, year
- **Game:** Barcode, platform, publisher, year, genre

## Offline-First Architecture

The application implements offline-first functionality:

1. **Local Database:** SQLite via `sqflite` for offline data persistence
2. **Sync Queue:** Operations queued when offline, executed when online
3. **Conflict Resolution:** Last-write-wins with timestamp comparison
4. **Background Sync:** Automatic sync on app resume and network reconnect

### Sync Flow
```
User Action → Local DB Update → Sync Queue Entry → [Wait for Network] → Firebase Update → Queue Clear
```

## External API Integrations

### Google Books API
- **Purpose:** Book metadata lookup by ISBN or text search
- **Endpoints:** Volume search
- **Data:** Title, authors, publisher, publication year, thumbnail

### Discogs API
- **Purpose:** Vinyl/music metadata lookup by barcode or text search
- **Authentication:** User token (configured in app)
- **Data:** Artist, title, label, format, year, cover art

### Open Library API
- **Purpose:** Fallback for book lookup when Google Books fails
- **Endpoints:** ISBN search, book data
- **Data:** Title, authors, publication year

## Security Model

### Firebase Security Rules
- **Firestore Rules:** Document-level access control based on household membership
- **Storage Rules:** User-scoped photo access with household sharing
- **Authentication:** Email/password, account creation flow
- **Member Approval:** Pending users must be approved by existing members

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for complete security rule configuration.

## Navigation Flow

### Primary Screens
1. **Auth Flow:** Login → Register → Email Verification
2. **Household Flow:** Create/Join Household → Member Approval (if joining)
3. **Main App:** Item List → Item Details
4. **Container Management:** Container List → Container View → Item Details
5. **Item Creation:** Add Item → Select Type → Scan/Manual Entry → Save
6. **Scanning:** Barcode Scan → Book/Vinyl Specific → Preview → Add to Collection

### Navigation Patterns
- **Hierarchical:** Container → Items in Container
- **Tab-based:** Category filtering within screens
- **Modal:** Dialogs for confirmations, forms, previews
- **Drawer:** Main navigation menu (future consideration)

## Design Patterns

### Successful Patterns Implemented

1. **Composition over Inheritance:** Building complex widgets from simpler ones
2. **Factory Constructors:** Multiple modes for widgets (e.g., `CategoryTabsBuilder.static()` vs `.dynamic()`)
3. **Generic Widgets:** Type-safe reusability (e.g., `SearchResultsView<T>`)
4. **Callback Pattern:** Flexible event handling without tight coupling
5. **Repository Pattern:** Data access abstraction layer
6. **Service Layer:** Business logic separation from UI

## Code Organization

```
lib/
├── main.dart                          # App entry point
├── models/                            # Data models
│   ├── user.dart
│   ├── household.dart
│   ├── container.dart
│   ├── item.dart
│   └── book.dart, vinyl.dart, game.dart
├── repositories/                      # Data access layer
│   ├── auth_repository.dart
│   ├── household_repository.dart
│   ├── container_repository.dart
│   └── item_repository.dart
├── services/                          # Business logic
│   ├── book_lookup_service.dart
│   ├── vinyl_lookup_service.dart
│   ├── sync_service.dart
│   └── image_service.dart
├── ui/
│   ├── screens/                       # Full-screen views
│   │   ├── auth/
│   │   ├── household/
│   │   ├── item/
│   │   ├── container/
│   │   └── scanning/
│   └── widgets/                       # Reusable components
│       ├── common/                    # General widgets
│       └── form/                      # Form fields
└── utils/                             # Helpers and utilities
    ├── text_search_helper.dart
    └── validators.dart
```

## Performance Considerations

1. **Lazy Loading:** Items loaded on-demand, not all at once
2. **Image Caching:** Thumbnail caching with Firebase Storage URLs
3. **Pagination:** Future consideration for large collections
4. **Async Operations:** Non-blocking UI with proper loading states
5. **Widget Reuse:** Minimized widget rebuilds through targeted state updates

## Testing Strategy

### Current State
- Manual testing of critical flows
- Firebase Rules testing via simulator
- Compilation checks via `fvm flutter analyze`

### Recommended
- Unit tests for utilities and services
- Widget tests for reusable components
- Integration tests for critical user flows
- Firebase emulator for local testing

See [development/TESTING.md](development/TESTING.md) for the complete testing plan.

## Refactoring History

The application has undergone significant refactoring to reduce code duplication and improve maintainability:

- **Phase 1:** Created 7 initial reusable widgets, removed ~342 LOC
- **Phase 2 & 3:** Created 9 additional widgets, removed ~683 LOC
- **Total:** 16 reusable widgets, ~1,025 LOC reduction

Detailed refactoring history is available in [archive/2025-11-refactoring/](archive/2025-11-refactoring/).

## Future Architecture Considerations

1. **Container Card Widget:** Extract complex container card (~190 LOC)
2. **Pagination:** Implement for large item lists
3. **Local Search:** Full-text search in local SQLite database
4. **Background Sync:** Periodic background sync with WorkManager
5. **Analytics:** Track usage patterns and feature adoption
6. **Error Reporting:** Crash reporting with Sentry or Firebase Crashlytics
7. **Feature Flags:** Remote configuration for gradual feature rollout

## Key Success Factors

The architecture has been successful due to:

1. **Consistent Patterns:** Reusable widgets enforce consistent UX
2. **Clear Separation:** UI, services, and data layers are well-defined
3. **Type Safety:** Strong typing catches errors at compile time
4. **Modularity:** Features are loosely coupled and independently testable
5. **Offline Support:** Sync queue enables reliable offline operation

## References

- [Features Documentation](FEATURES.md)
- [Firebase Setup Guide](FIREBASE_SETUP.md)
- [Testing Plan](development/TESTING.md)
- [Project Roadmap](ROADMAP.md)
