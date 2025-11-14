# OurArchive Features

Complete feature overview for the household inventory management application.

---

## Core Concept

OurArchive helps families and friends track shared items through a collaborative, hierarchical organization system. Users can create households with unique invite codes, organize items in nested containers (rooms → shelves → boxes), and maintain a shared inventory with photos and metadata.

---

## Authentication & Accounts

### Anonymous Sign-In
- Quick start without registration
- Temporary account with full functionality
- Can upgrade to permanent account later

### Email/Password Authentication
- Standard email and password registration
- Secure account with password reset capability
- Account recovery options

### Account Linking
- **Upgrade anonymous to email account**
- Preserves all households and data during upgrade
- Seamless transition without data loss

### User Profiles
- Display name customization
- Profile updates synced across all households
- Visible to all household members

---

## Household Management

### Create Household
- **6-character invite codes** with checksum validation
- Automatic code generation with collision detection
- Household owner role assigned to creator
- Members list with role management

### Join Household
- Join via 6-character code
- Automatic code validation (checksum + existence check)
- Member approval system for controlled access

### Member Approval System
- **Roles:**
  - **Owner** - Full control (1 per household)
  - **Member** - Can create, edit, and delete items
  - **Viewer** - Read-only access
  - **Pending** - Awaiting approval, no access to data

- **Approval Flow:**
  1. User joins with code → Status: Pending
  2. Owner/Admin reviews request
  3. Owner approves with role selection (Member/Viewer)
  4. User gains access based on assigned role

### Household Settings
- Rename household
- View all members and roles
- Manage member permissions
- Leave household option
- Delete household (owner only)

---

## Container Organization

### Hierarchical Structure
- **Infinite nesting:** Rooms → Shelves → Boxes → Sub-boxes → etc.
- **Container types:** Room, Shelf, Box, Fridge, Drawer, Custom
- Drag-to-reorder (sort order persistence)
- Visual hierarchy with indentation

### Container Features
- **Create containers** at any level
- **Edit container** name and type
- **Move containers** between parents
- **Delete containers** (with item handling)
- **Navigate** through container hierarchy
- **Breadcrumb navigation** showing current path

### Container-First Navigation
- Start at household level (rooms view)
- Tap to drill down into containers
- View items at any container level
- Clear visual separation of containers vs. items

### Container Selection
- **Smart container picker** when creating items
- Shows full hierarchy with indentation
- Displays container type icons
- Allows moving items between containers

---

## Item Management

### Create Items
- **Quick add via FAB** (Floating Action Button)
- Photo capture or selection from gallery
- Container assignment during creation
- Optional metadata: name, description, tags
- Automatic timestamp tracking

### Item Details
- Full-screen item view
- Photo with zoom/pan viewer
- Edit all item properties
- Move to different container
- Delete with confirmation

### Item Types
- Books (with ISBN scanning)
- Electronics
- Clothing
- Furniture
- Kitchen items
- General items
- Custom categories

### Photo Management
- **Photo upload with compression**
- Automatic thumbnail generation
- Firebase Storage integration
- 10MB file size limit
- Full-screen photo viewer with gestures:
  - Pinch to zoom
  - Pan to move
  - Double-tap to zoom
  - Tap to dismiss

---

## Book Scanning Feature

### ISBN Barcode Scanner
- **Mobile camera barcode scanning**
- Automatic ISBN-10 and ISBN-13 recognition
- Real-time barcode detection
- Flashlight toggle for low-light scanning

### Book Metadata Lookup
- **Dual API fallback system:**
  1. Google Books API (primary)
  2. Open Library API (fallback)
- Auto-populates book information:
  - Title
  - Authors
  - Publisher
  - Published date
  - ISBN numbers
  - Cover image
  - Description
  - Page count

### Batch Scanning
- Scan multiple books in sequence
- Queue books for review
- Edit details before saving
- Bulk add to container

---

## Search & Filtering

### Search Capabilities
- **Full-text search** across item names
- Search within specific household
- Search results with thumbnails
- Quick navigation to item details

### Advanced Filters
- **Filter by type** (Book, Electronics, etc.)
- **Filter by container** (Room, Shelf, Box)
- **Filter by tags**
- **Combined filters** for precise results
- Clear all filters option

### Sorting
- Sort by name (A-Z)
- Sort by creation date (newest/oldest)
- Sort by last modified
- Custom sort order (manual drag-and-drop)

---

## Data Management

### Offline-First Architecture
- **Sync queue** for offline operations
- Automatic retry on connection restore
- Conflict resolution
- Local caching for fast access

### Data Persistence
- Firestore real-time database
- Automatic sync across devices
- Multi-device support
- Data backup via Firebase

### Photo Storage
- Firebase Cloud Storage
- Automatic compression before upload
- Thumbnail generation
- Efficient bandwidth usage

---

## User Interface

### Material Design 3
- Modern, clean interface
- Consistent design language
- Adaptive layouts for different screen sizes
- Dark mode support (system theme)

### Navigation
- Bottom navigation bar
- Breadcrumb trails for deep navigation
- Back button support
- Context-aware actions

### Responsive Layouts
- Mobile-first design
- Tablet optimization
- Landscape mode support

### User Experience
- **Fast load times** with caching
- **Optimistic UI updates** for instant feedback
- **Error handling** with user-friendly messages
- **Loading indicators** for network operations

---

## Security & Privacy

### Authentication Security
- Firebase Authentication
- Secure password hashing
- Token-based session management
- Automatic token refresh

### Data Security
- **Firestore Security Rules:**
  - Role-based access control
  - Household-scoped permissions
  - User can only edit own profile
  - Only household members can access data

- **Storage Security Rules:**
  - Authenticated uploads only
  - Owner metadata validation
  - File size limits
  - Household-scoped access

### Privacy
- Data visible only to household members
- Pending members cannot access data until approved
- Owner-only admin functions
- Secure invite code system

---

## Developer Features

### Debug Mode
- Test data generation with Faker
- Quick household setup
- Sample items creation
- Development-only access

### Error Handling
- Firebase Crashlytics integration
- Automatic crash reporting
- Error logging for debugging
- User-friendly error messages

### Testing
- Unit tests for core logic
- Widget tests for UI components
- Integration tests for workflows
- Mock Firebase for testing

---

## Technical Features

### State Management
- **Riverpod** for reactive state
- Centralized provider architecture
- Efficient rebuilds
- Dependency injection

### Performance
- Image compression before upload
- Lazy loading for large lists
- Efficient Firestore queries with indexes
- Cached network images

### Connectivity
- **Connection status monitoring**
- Offline mode detection
- Automatic reconnection
- Queue-based sync on restore

---

## Supported Platforms

- ✅ **Android** (primary target)
- ✅ **iOS** (supported)
- ⏳ **Web** (future consideration)

---

## Dependencies

### Core
- Flutter SDK
- Dart 3.x

### Firebase
- firebase_core
- cloud_firestore
- firebase_auth
- firebase_storage
- firebase_crashlytics

### State Management
- flutter_riverpod

### Features
- mobile_scanner (barcode scanning)
- image_picker (photo selection)
- flutter_image_compress (photo optimization)
- cached_network_image (efficient image loading)
- connectivity_plus (network monitoring)

### Utilities
- http (API calls)
- uuid (unique IDs)
- path_provider (file system)
- csv (data export)
- share_plus (sharing)
- flutter_local_notifications (notifications)

---

## Current Limitations

### Known Issues
1. Debug screen has Faker API compilation errors (dev-only)
2. Minor deprecated parameter warnings in dropdown widgets
3. Member "deny" functionality uses workaround
4. Limited unit test coverage

### Not Yet Implemented
- Password reset flow (backend ready, UI pending)
- Email verification
- Push notifications for household invites
- Data export/import
- Bulk operations
- Item history/audit log
- Shopping list integration
- Item lending tracking
- Expiration date reminders

---

## Changelog

See implementation history in `/docs/archive/` for detailed feature completion timeline.

---

## Future Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features and development phases.
