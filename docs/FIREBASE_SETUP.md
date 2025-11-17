# OurArchive Setup Guide

Complete guide for setting up Firebase backend and deploying security rules for OurArchive.

## Prerequisites

- Firebase project created at [Firebase Console](https://console.firebase.google.com/)
- Firebase CLI installed (optional, for command-line deployment)

---

## 1. Enable Authentication

### Enable Email/Password Sign-In

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your **OurArchive** project
3. Navigate to **Authentication** → **Sign-in method** tab
4. Find **Email/Password** in the list of providers
5. Click on it and toggle **Enable** switch to ON
6. Click **Save**

### Enable Anonymous Authentication

1. In the same **Sign-in method** tab
2. Find **Anonymous** provider
3. Toggle **Enable** switch to ON
4. Click **Save**

### Optional: Enable Additional Providers

Consider enabling:
- **Google Sign-In** - Recommended for easier sign-in experience
- **Apple Sign-In** - Required for App Store if you have other social logins

---

## 2. Deploy Firestore Security Rules

Security rules control who can read and write data in your Firestore database.

### Method 1: Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your OurArchive project
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the contents of `firebase/firestore.rules` from your project
5. Paste into the rules editor
6. Click **Publish**

### Method 2: Firebase CLI

```bash
cd /Users/gustafeden/gustaf/OurArchive
firebase deploy --only firestore:rules
```

### Rules Overview

The rules implement **household-based access control**:

- **Users Collection** (`/users/{uid}`)
  - Users can read any authenticated user's profile
  - Users can only write to their own profile

- **Households Collection** (`/households/{hid}`)
  - Any authenticated user can create a household
  - Only members (owner/member/viewer) can read household data
  - Only owners can update or delete households

- **Items Subcollection** (`/households/{hid}/items/{itemId}`)
  - Members can create items
  - Members can read all items in their household
  - Only the creator or household owner can update/delete items

- **Containers Collection** (`/containers/{containerId}`)
  - Household members can create, read, update, and delete containers
  - Access controlled by `householdId` membership

**Helper Functions:**
- `isMember(hid)` - Checks if user is owner, member, or viewer (not pending)
- `isOwner(hid)` - Checks if user is the household owner
- `isPending(hid)` - Checks if user has pending membership

⚠️ **Security Warning:** Until you deploy these rules, your Firestore database may be open to all users. Deploy as soon as possible!

---

## 3. Deploy Storage Security Rules

Storage rules control who can upload and access photos.

### Method 1: Firebase Console (Recommended)

1. In Firebase Console, navigate to **Storage** → **Rules** tab
2. Copy the contents of `firebase/storage.rules`
3. Paste into the rules editor
4. Click **Publish**

### Method 2: Firebase CLI

```bash
firebase deploy --only storage
```

### Storage Rules Overview

- Photos are stored at: `/households/{hid}/{itemId}/{fileName}`
- Anyone authenticated can read photos
- Only authenticated users can upload photos
- Uploader must set their uid in `metadata.owner`
- 10MB file size limit enforced

---

## 4. Create Firestore Indexes

Indexes are required for efficient queries. Firebase provides two easy ways to create them.

### Method 1: Use Error Link (Easiest!)

When you run a query that needs an index, Firestore provides a direct link in the error message:

1. Run your app and trigger the query
2. Look for the error message with a link like:
   ```
   https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes?create_composite=...
   ```
3. Click the link
4. Click **Create Index** button
5. Wait 2-5 minutes for index to build
6. Try the app again

### Method 2: Create Manually in Console

1. Navigate to **Firestore Database** → **Indexes** tab
2. Click **Add Index** for each index needed

**Required Indexes:**

**Index 1 - Items by Type:**
- Collection: `items`
- Fields:
  - `type` (Ascending)
  - `createdAt` (Descending)
- Query scope: Collection

**Index 2 - Items Archive Status:**
- Collection: `items`
- Fields:
  - `archived` (Ascending)
  - `sortOrder` (Ascending)
- Query scope: Collection

**Index 3 - Items with Deletion:**
- Collection: `items`
- Fields:
  - `deletedAt` (Ascending)
  - `sortOrder` (Ascending)
  - `createdAt` (Descending)
- Query scope: Collection

**Index 4 - Top-Level Containers (Rooms):**
- Collection: `containers`
- Fields:
  - `householdId` (Ascending)
  - `parentId` (Ascending)
  - `sortOrder` (Ascending)
  - `createdAt` (Ascending)
- Query scope: Collection

**Index 5 - Child Containers:**
- Collection: `containers`
- Fields:
  - `parentId` (Ascending)
  - `sortOrder` (Ascending)
  - `createdAt` (Ascending)
- Query scope: Collection

### Method 3: Firebase CLI

```bash
cd /Users/gustafeden/gustaf/OurArchive
firebase deploy --only firestore:indexes
```

⏱️ **Note:** Indexes take 2-5 minutes to build, regardless of deployment method.

---

## 5. Deploy All at Once

### Using Firebase CLI

Deploy everything in one command:

```bash
cd /Users/gustafeden/gustaf/OurArchive

# Deploy all Firebase resources
firebase deploy

# Or deploy only Firestore (rules + indexes)
firebase deploy --only firestore

# Or deploy Firestore and Storage
firebase deploy --only firestore,storage
```

**First-time CLI setup:**

If you haven't used Firebase CLI before:

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize project (if firebase.json doesn't exist)
firebase init

# Select your project
firebase use --add
```

---

## 6. Verify Deployment

After deploying rules and indexes, verify everything is working:

### Check Firebase Console

1. **Firestore Rules** - Should show "Last published: [current date/time]"
2. **Storage Rules** - Should show "Last published: [current date/time]"
3. **Firestore Indexes** - All indexes should show status: "Enabled"

### Test in Your App

Run these test scenarios:

**Test 1: Authentication**
```dart
// Should succeed for enabled providers
await FirebaseAuth.instance.signInAnonymously();
await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: 'test@example.com',
  password: 'password123',
);
```

**Test 2: Create Household**
```dart
// Should succeed for any authenticated user
await FirebaseFirestore.instance.collection('households').add({
  'name': 'Test Home',
  'createdBy': currentUserId,
  'members': {currentUserId: 'owner'},
  'code': 'ABC123',
  'createdAt': FieldValue.serverTimestamp(),
});
```

**Test 3: Read Items (Authorized)**
```dart
// Should succeed if user is a member
final items = await FirebaseFirestore.instance
  .collection('households')
  .doc(householdId)
  .collection('items')
  .get();
```

**Test 4: Read Items (Unauthorized)**
```dart
// Should FAIL if user is not a member
final items = await FirebaseFirestore.instance
  .collection('households')
  .doc(someOtherHouseholdId)
  .collection('items')
  .get();
// Expected: permission-denied error
```

**Test 5: Upload Photo**
```dart
// Should succeed with proper metadata
final metadata = SettableMetadata(
  customMetadata: {'owner': currentUserId},
);
await FirebaseStorage.instance
  .ref('households/$hid/$itemId/image.jpg')
  .putFile(photoFile, metadata);
```

**Test 6: Create and Query Containers**
```dart
// Should succeed for household members
await FirebaseFirestore.instance.collection('containers').add({
  'name': 'Living Room',
  'type': 'room',
  'householdId': householdId,
  'parentId': '',
  'sortOrder': 0,
  'createdAt': FieldValue.serverTimestamp(),
});
```

---

## Troubleshooting

### Issue: Rules deployment fails
**Solution:**
- Ensure you're logged in: `firebase login`
- Select correct project: `firebase use --add`
- Check `firebase.json` configuration

### Issue: "Query requires an index"
**Solution:**
- Firebase provides a direct link in error message to create the index
- Or manually create from the console/CLI
- Wait 2-5 minutes for index to build after creation

### Issue: Storage uploads fail
**Solution:**
- Verify `metadata.owner` field matches authenticated user's uid
- Check file size is under 10MB limit
- Ensure storage rules are deployed

### Issue: Permission denied errors
**Solution:**
1. Verify user is authenticated
2. Check user is a member of the household (not pending)
3. For updates/deletes, verify user is creator or owner
4. Wait 30 seconds after publishing rules (propagation time)
5. Completely restart your app (not just hot reload)

### Issue: Still getting errors after deployment
**Solution:**
- Verify deployment to correct Firebase project
- Check Firebase Console to confirm rules are published
- Clear app cache and restart
- Check Firebase Console logs for specific error details

### Need to Rollback?
- Firebase Console → Firestore → Rules tab
- Click **History**
- Select previous version and restore

---

## Configuration Files

The setup uses these configuration files in your project:

- `firebase/firestore.rules` - Firestore database security rules
- `firebase/storage.rules` - Firebase Storage security rules
- `firebase/firestore.indexes.json` - Firestore query indexes
- `firebase.json` - Firebase project configuration

---

## Next Steps

After completing setup:

1. ✅ Test authentication flow (anonymous and email)
2. ✅ Test household creation
3. ✅ Test joining household by code
4. ✅ Test member approval system
5. ✅ Test container creation (rooms, shelves, boxes)
6. ✅ Test item CRUD operations
7. ✅ Test photo uploads
8. ✅ Verify pending members can't access data
9. ✅ Verify non-members can't access household data

## Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Storage Security Rules Guide](https://firebase.google.com/docs/storage/security)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
