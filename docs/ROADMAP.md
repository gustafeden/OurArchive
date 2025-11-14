# OurArchive Development Roadmap

**Last Updated:** November 14, 2025
**Current Status:** Beta - Core features complete, ready for testing

---

## Current State: Beta-Ready ✅

The app has strong fundamentals with working authentication, organization, and item management. The container system is well-designed and flexible.

**Core functionality complete:**
- Authentication (anonymous & email)
- Household management with invite codes
- Member approval system
- Hierarchical container organization
- Item creation with photos
- Offline-first sync queue
- Search functionality
- Profile management

---

## Known Issues

### High Priority
1. **Debug screen compilation errors** - Faker API issues (dev-only, 5 min fix)
2. **Deprecated parameter warnings** - DropdownButtonFormField uses old API (10 min fix)
3. **Member deny functionality** - Uses workaround instead of proper removal (15 min fix)

### Medium Priority
4. **No comprehensive unit tests** - Limited test coverage
5. **Minor deprecation warnings** - Various deprecated APIs in use

See implementation history in `/docs/archive/` for detailed completion timeline.

---

## Development Phases

### Phase 1: Polish & Stability (1-2 weeks)

**Focus:** Make app production-ready

#### Critical Fixes
- [ ] Fix debug screen faker errors
- [ ] Replace deprecated `value` with `initialValue`
- [ ] Add proper member removal function
- [ ] Add container delete validation

#### Essential Features
- [ ] Item detail/edit screen
- [ ] Delete item functionality
- [ ] Item move between containers
- [ ] Better error handling on network failures
- [ ] Loading states for all async operations

**Goal:** Stable, bug-free core experience

---

### Phase 2: Enhanced UX (2-3 weeks)

**Focus:** Professional-grade inventory management

#### User Management
- [ ] User profiles with display names
- [ ] Avatar upload
- [ ] Household member list screen
- [ ] Remove/change member roles
- [ ] Household settings screen

#### Item Management
- [ ] Item detail screen with full view
- [ ] Edit item details
- [ ] Item history/audit log
- [ ] Item notes/comments
- [ ] Multiple photos per item

#### Organization
- [ ] Drag-and-drop to reorganize items
- [ ] Smart suggestions for container placement
- [ ] Recently added items section
- [ ] Favorites/quick access items

**Goal:** Polished, professional user experience

---

### Phase 3: Advanced Features (3-4 weeks)

**Focus:** Power user features

#### Search & Discovery
- [ ] Advanced filters (type, tag, container, date range)
- [ ] Enhanced barcode scanning
- [ ] QR code generation for containers
- [ ] Item suggestions based on barcode
- [ ] Recent searches

#### Import/Export
- [ ] CSV export of inventory
- [ ] PDF report generation
- [ ] Bulk import from CSV
- [ ] Backup/restore functionality

#### Notifications
- [ ] Low stock alerts
- [ ] Expiration date reminders
- [ ] New member join notifications
- [ ] Daily/weekly summary emails

#### Analytics
- [ ] Item count by container
- [ ] Most/least used items
- [ ] Household activity feed
- [ ] Value tracking (optional)

**Goal:** Feature-rich platform for power users

---

### Phase 4: Mobile Excellence (4-5 weeks)

**Focus:** App Store ready

#### Performance
- [ ] Image caching with flutter_cache_manager
- [ ] Pagination for large item lists
- [ ] Virtual scrolling for 1000+ items
- [ ] Background sync optimization
- [ ] Memory profiling and optimization

#### Platform Integration
- [ ] Apple Sign In
- [ ] Siri shortcuts ("Show items in garage")
- [ ] Widgets (recent items, household summary)
- [ ] Share extension (add items from Photos)
- [ ] 3D Touch quick actions

#### Polish
- [ ] Dark mode
- [ ] Haptic feedback
- [ ] Animations and transitions
- [ ] Custom icons for container types
- [ ] Onboarding tutorial

**Goal:** Premium mobile app experience

---

### Phase 5: Collaboration & Sharing (5-6 weeks)

**Focus:** Team-oriented features

#### Collaboration
- [ ] Item check-in/check-out system
- [ ] Item reservation ("I'm using this")
- [ ] Activity feed per household
- [ ] @mentions in item notes
- [ ] Shared shopping lists

#### Sharing
- [ ] Share item via link (temporary access)
- [ ] Public household view (read-only link)
- [ ] Generate shareable inventory lists
- [ ] Export to other apps (Notion, Airtable)

#### Advanced Organization
- [ ] Tags with colors
- [ ] Custom item fields
- [ ] Container templates (e.g., "Kitchen Setup")
- [ ] Item duplication
- [ ] Conditional rules (auto-organize)

**Goal:** Collaborative household management

---

## Innovative Feature Ideas

### High Impact Features

#### 1. Visual Container Map
- Interactive 2D map of room layout
- Drag containers to position them visually
- Click on map location to see items
- Photo overlay of actual room

#### 2. AR Item Finder
- Point camera at room
- Overlay shows item locations
- "Find my X" guided search
- Integration with ARKit/ARCore

#### 3. Smart Inventory Assistant
- AI-powered suggestions: "Running low on batteries?"
- Automatic categorization from photos
- Voice commands: "Add milk to kitchen fridge"
- Predictive organization

#### 4. Maintenance Tracking
- Track expiration dates
- Service schedules for equipment
- Warranty information
- Replacement reminders

#### 5. Shopping Integration
- Generate shopping lists from low stock
- Price tracking for items
- Reorder from favorite stores
- Receipt scanning and auto-add

### Nice to Have Features

#### 6. Multi-Location Support
- Multiple households (home, cabin, storage unit)
- Move items between locations
- Location-aware suggestions
- GPS tracking for borrowed items

#### 7. Insurance Documentation
- Valuation tracking
- Receipt attachment
- Insurance report generation
- Loss documentation

#### 8. Social Features
- Borrow from friends' inventories
- Community sharing (tool libraries)
- Item recommendations
- Inventory templates from community

---

## Technical Roadmap

### Code Quality Improvements
- [ ] Add comprehensive unit tests
- [ ] Add integration tests for critical flows
- [ ] Add widget tests for all screens
- [ ] Improve error logging
- [ ] Add performance monitoring

### Architecture Enhancements
- [ ] Extract reusable widgets into separate files
- [ ] Create theme configuration file
- [ ] Add dependency injection for services
- [ ] Implement repository pattern consistently
- [ ] Add caching layer

### Documentation
- [ ] Add inline documentation for services
- [ ] Create architecture diagram
- [ ] Document state management patterns
- [ ] Add contribution guidelines
- [ ] Create API documentation

### Infrastructure
- [ ] Set up CI/CD pipeline
- [ ] Add automated testing
- [ ] Set up staging environment
- [ ] Configure analytics (Firebase Analytics)
- [ ] Set up error tracking dashboard

---

## Timeline Estimates

### Minimum Viable Product (MVP+)
**Timeline:** 2 weeks
**Scope:** Fix bugs, add essentials, basic polish
**Status:** Launch-ready for friends & family testing

### Recommended Release
**Timeline:** 6-8 weeks
**Scope:** MVP + key features + polish
**Status:** Public beta ready

### Full Feature Set
**Timeline:** 12 weeks
**Scope:** All Phase 1-3 features + testing
**Status:** Production ready for App Store

---

## Success Metrics

### Usage Metrics
- Daily active users
- Items added per user
- Households created
- Member invites sent
- Search queries performed

### Engagement Metrics
- Session length
- Items added per session
- Photos uploaded
- Containers created
- Return rate (7-day, 30-day)

### Quality Metrics
- Crash-free rate (target: 99.9%)
- App load time (target: <2s)
- Photo upload success rate
- Sync success rate
- User retention (target: 80% at 30 days)

---

## Potential Monetization (Future Consideration)

### Freemium Model

#### Free Tier
- 1 household
- 100 items limit
- 5 containers
- 1 GB photo storage
- Basic features

#### Premium Tier ($4.99/month or $39.99/year)
- Unlimited households
- Unlimited items
- Unlimited containers
- 50 GB photo storage
- Advanced search & filters
- CSV export
- Priority support
- Item value tracking
- Maintenance tracking

#### Family Tier ($9.99/month)
- All Premium features
- Up to 5 households
- 200 GB shared storage
- Family sharing
- Admin controls

### Alternative Models
- One-time purchase: $29.99
- Pay-per-household: $2.99/household/year
- Enterprise: Custom pricing for businesses

---

## Technologies to Consider

### Current Stack ✅
- Flutter/Dart
- Firebase (Auth, Firestore, Storage, Crashlytics)
- Riverpod state management

### Potential Additions
- **flutter_cache_manager** - Better image caching
- **drift** - Local SQL database for better offline support
- **go_router** - Improved navigation with deep linking
- **freezed** - Immutable models with code generation
- **json_serializable** - Better JSON handling
- **flutter_local_notifications** - Push notifications
- **mobile_scanner** - Barcode scanning (already in pubspec)

---

## Recommended Next Steps

### Immediate (This Week)

1. **Fix critical bugs**
   - Debug screen faker errors
   - Member removal function
   - Deprecated value warnings

2. **Add item detail screen**
   - View all item details
   - Edit functionality
   - Delete with confirmation
   - Share item info

3. **Improve item display**
   - Show actual photo thumbnails
   - Better item cards with more info
   - Quick actions (edit, delete, move)

### Next 2 Weeks

4. **Container improvements**
   - Delete validation
   - Move items when deleting container
   - Container detail screen
   - Edit container properties

5. **User experience**
   - Better loading states
   - Empty state improvements
   - Success animations
   - Error recovery flows

6. **Search & filters**
   - Type filter dropdown
   - Container filter
   - Tag-based search
   - Search history

### Next Month

7. **User profiles**
   - Display names
   - Avatars
   - User settings
   - Notification preferences

8. **Notifications**
   - New member requests
   - Item added/removed
   - Low stock alerts

9. **Advanced organization**
   - Item move between containers
   - Bulk operations
   - Item duplication
   - Container templates

---

## Long-Term Vision

### 3 Months
**Status:** Feature-Rich Platform
Professional inventory management with advanced search, notifications, and analytics

### 6 Months
**Status:** Mobile Excellence
Premium app store presence with platform integration and polished UX

### 12 Months
**Status:** Market Leader
AR features, AI assistance, community features, multi-platform support (web, desktop)

---

**Questions or suggestions?** This roadmap is a living document and will evolve based on user feedback and priorities.
