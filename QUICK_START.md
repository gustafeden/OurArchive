# OurArchive - Quick Start Guide

## 🚀 Ready to Run!

Your OurArchive app is fully implemented and ready for testing.

## Prerequisites Checklist

- [x] Flutter installed (3.9.0+)
- [x] Firebase project created
- [x] iOS/Android Firebase configuration files in place
- [ ] **Firebase security rules deployed** ⚠️ IMPORTANT

## First Time Setup

### 1. Deploy Firebase Rules (Critical!)

Your database is currently **open to all users** until you deploy the security rules.

**Option A: Use Firebase Console (Recommended)**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your OurArchive project
3. Deploy rules manually (see [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for details)

**Option B: Use Firebase CLI**
```bash
firebase login
firebase use --add  # Select your project
firebase deploy --only firestore,storage
```

### 2. Run the App

```bash
cd our_archive
flutter run
```

## First Test Flow

### Step 1: Sign In
- Tap "Get Started" for anonymous sign-in
- You'll be taken to the household list (empty)

### Step 2: Create Household
- Tap the "Create" floating action button
- Enter a household name (e.g., "My Home")
- Tap "Create Household"
- Note the 6-character code displayed
- Tap "Done"

### Step 3: Add Items
- Tap on your newly created household
- Tap the "+ Add Item" button
- Fill in item details:
  - Title: "Power Drill"
  - Type: tool
  - Location: "Garage"
  - Quantity: 1
  - Tags: "power tools, black"
- Optionally take a photo
- Tap "Save Item"

### Step 4: Test Search
- Add a few more items
- Use the search bar to filter items
- Verify real-time updates work

### Step 5: Test Household Sharing (Optional)
- Share the 6-character code with someone
- Have them install the app
- They sign in anonymously
- Tap "Join" button
- Enter the code
- As owner, you'll see them in pending members (UI for approval coming in Week 2)

## Debug Mode

Access debug tools during development:

```dart
// Add this to any screen's app bar actions
IconButton(
  icon: Icon(Icons.bug_report),
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DebugScreen(),
    ),
  ),
)
```

Debug features:
- Sync queue monitoring
- Generate 50/100 test items
- Network error simulation

## Common Commands

```bash
# Run on specific device
flutter run -d <device-id>

# Build for iOS
flutter build ios --debug --no-codesign

# Build for Android
flutter build apk --debug

# Check for issues
flutter analyze

# Run tests
flutter test

# Clean and rebuild
flutter clean && flutter pub get && flutter run
```

## Troubleshooting

### "Permission denied" errors
**Cause:** Firebase rules not deployed
**Fix:** Deploy rules using [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)

### Items not appearing
**Cause:** Not a member of the household
**Fix:** Verify you created or joined the household correctly

### Photos not uploading
**Cause:** Storage rules not deployed
**Fix:** Deploy storage rules

### Sync queue stuck
**Cause:** Offline or network error
**Fix:** Check connectivity, use debug screen to monitor queue

### Build fails
**Cause:** Dependencies not installed
**Fix:** Run `flutter pub get`

## Project Structure Quick Reference

```
our_archive/
├── lib/
│   ├── main.dart                      # App entry point
│   ├── core/sync/sync_queue.dart      # Offline sync
│   ├── data/
│   │   ├── models/                    # Data models
│   │   ├── services/                  # Business logic
│   │   └── repositories/              # Data access
│   ├── providers/providers.dart       # State management
│   ├── ui/screens/                    # All screens
│   └── debug/debug_screen.dart        # Debug tools
├── firebase/                          # Security rules
└── test/                              # Tests
```

## Key Files to Know

| File | Purpose |
|------|---------|
| `lib/providers/providers.dart` | All Riverpod providers |
| `firebase/firestore.rules` | Database security rules |
| `firebase/storage.rules` | Photo upload security |
| `lib/data/services/household_service.dart` | Household management |
| `lib/data/repositories/item_repository.dart` | Item CRUD operations |

## App Flow

```
Launch
  ↓
AuthGate (checks auth status)
  ↓
├─ Not signed in → WelcomeScreen
│                     ↓
│                  Sign in anonymously
│                     ↓
└─ Signed in → HouseholdListScreen
                      ↓
               ├─ Create household
               └─ Join household
                      ↓
               ItemListScreen
                      ↓
               ├─ Add items
               ├─ Search items
               └─ View items
```

## What's Implemented (Week 1 MVP)

✅ Anonymous authentication
✅ Create households with codes
✅ Join households by code
✅ Add/edit/delete items
✅ Photo capture and upload
✅ Search functionality
✅ Offline-first sync
✅ Real-time updates

## What's Coming (Week 2)

📋 Email/password sign-in
📋 Member approval UI
📋 Advanced filters
📋 Barcode scanning
📋 CSV export
📋 Item detail view

## Performance Tips

1. **Use the debug screen** to generate test data for stress testing
2. **Monitor the sync queue** to see offline operations
3. **Test offline mode** by enabling airplane mode
4. **Check Firestore indexes** are created (might take a few minutes)

## Security Reminder

⚠️ **CRITICAL:** Deploy Firebase security rules before sharing the app with others!

Without deployed rules, anyone can:
- Read all households
- Modify any data
- Delete everything

See [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for instructions.

## Next Steps

1. ✅ Deploy Firebase rules
2. ✅ Test the app on your device
3. ✅ Create a test household
4. ✅ Add some test items
5. ✅ Share code with a friend to test joining
6. 📋 Implement Week 2 features
7. 📋 TestFlight deployment

## Support

- Check [docs/README.md](docs/README.md) for complete documentation index
- See [docs/archive/ORIGINAL_PLAN.md](docs/archive/ORIGINAL_PLAN.md) for original feature specification
- See [docs/archive/IMPLEMENTATION_SUMMARY.md](docs/archive/IMPLEMENTATION_SUMMARY.md) for what was initially built
- Review [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for security rules
- Check [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for current architecture

## Ready to Code More?

The codebase is well-structured and ready for:
- Adding new features
- Customizing UI
- Extending functionality
- Adding tests

All services are injectable via Riverpod, making testing and modification easy.

---

**Happy coding! 🎉**

*The foundation is solid. Now build something amazing!*
