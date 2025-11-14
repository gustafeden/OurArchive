# Firebase Security Rules Deployment Guide

## Overview

The Firebase security rules and indexes have been created in the `firebase/` directory. You'll need to deploy them manually to secure your Firebase project.

## Files Created

1. **firebase/firestore.rules** - Firestore database security rules
2. **firebase/storage.rules** - Firebase Storage security rules
3. **firebase/firestore.indexes.json** - Firestore query indexes
4. **firebase.json** - Firebase configuration file

## Deployment Methods

### Method 1: Using Firebase Console (Web UI)

#### Firestore Rules
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (OurArchive)
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the contents of `firebase/firestore.rules`
5. Paste into the rules editor
6. Click **Publish**

#### Storage Rules
1. In Firebase Console, navigate to **Storage** → **Rules** tab
2. Copy the contents of `firebase/storage.rules`
3. Paste into the rules editor
4. Click **Publish**

#### Firestore Indexes
1. In Firebase Console, navigate to **Firestore Database** → **Indexes** tab
2. Click **Add Index** for each index in `firebase/firestore.indexes.json`:

   **Index 1:**
   - Collection: `items`
   - Fields:
     - `type` (Ascending)
     - `createdAt` (Descending)
   - Query scope: Collection

   **Index 2:**
   - Collection: `items`
   - Fields:
     - `archived` (Ascending)
     - `sortOrder` (Ascending)
   - Query scope: Collection

   **Index 3:**
   - Collection: `items`
   - Fields:
     - `deletedAt` (Ascending)
     - `sortOrder` (Ascending)
     - `createdAt` (Descending)
   - Query scope: Collection

### Method 2: Using Firebase CLI

If you have Firebase CLI installed and initialized:

```bash
# Navigate to project root
cd /Users/gustafeden/gustaf/OurArchive

# Deploy all rules
firebase deploy --only firestore,storage

# Or deploy individually
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

**Note:** If you get deployment errors, you may need to:
1. Run `firebase login` first
2. Run `firebase use --add` to select your project
3. Ensure firebase.json is properly configured

## Security Rules Explanation

### Firestore Rules

The rules implement a **household-based access control** system:

- **Users Collection** (`/users/{uid}`)
  - Users can read any authenticated user's profile
  - Users can only write to their own profile

- **Households Collection** (`/households/{hid}`)
  - Any authenticated user can create a household
  - Only members (owner/member/viewer) can read household data
  - Only owners can update or delete households

- **Items Subcollection** (`/households/{hid}/items/{itemId}`)
  - Members can create items (must set createdBy to their uid)
  - Members can read all items in their household
  - Only the creator or household owner can update/delete items

**Helper Functions:**
- `isMember(hid)` - Checks if user is owner, member, or viewer (not pending)
- `isOwner(hid)` - Checks if user is the household owner
- `isPending(hid)` - Checks if user has pending membership

### Storage Rules

- Photos are stored at: `/households/{hid}/{itemId}/{fileName}`
- Anyone authenticated can read photos
- Only authenticated users can upload photos
- Uploader must set their uid in metadata.owner
- 10MB file size limit enforced

## Testing Your Rules

After deploying, test with these scenarios:

### Test 1: Create Household
```dart
// Should succeed for any authenticated user
await FirebaseFirestore.instance.collection('households').add({
  'name': 'Test Home',
  'createdBy': currentUserId,
  'members': {currentUserId: 'owner'},
  // ...
});
```

### Test 2: Read Items (Authorized)
```dart
// Should succeed if user is a member
final items = await FirebaseFirestore.instance
  .collection('households')
  .doc(householdId)
  .collection('items')
  .get();
```

### Test 3: Read Items (Unauthorized)
```dart
// Should FAIL if user is not a member
final items = await FirebaseFirestore.instance
  .collection('households')
  .doc(someOtherHouseholdId)
  .collection('items')
  .get();
// Expected: permission-denied error
```

### Test 4: Upload Photo
```dart
// Should succeed with proper metadata
final metadata = SettableMetadata(
  customMetadata: {'owner': currentUserId},
);
await FirebaseStorage.instance
  .ref('households/$hid/$itemId/image.jpg')
  .putFile(photoFile, metadata);
```

## Important Notes

⚠️ **Security Warning:** Until you deploy these rules, your Firestore database is open to all users (default test mode rules). Deploy ASAP!

✅ **Verification:** After deployment, check the Firebase Console to verify rules are active:
- Firestore Rules should show "Last published: [current date/time]"
- Storage Rules should show "Last published: [current date/time]"

📊 **Indexes:** Firestore will automatically create indexes when needed, but pre-creating them prevents deployment delays and ensures optimal query performance.

## Troubleshooting

### Issue: Rules deployment fails
**Solution:** Ensure you're logged in (`firebase login`) and have selected the correct project (`firebase use --add`)

### Issue: Queries fail with "requires an index"
**Solution:** Firebase will provide a direct link in the error message to create the missing index. Or manually create from the indexes.json file.

### Issue: Storage uploads fail
**Solution:** Verify the metadata.owner field matches the authenticated user's uid

### Issue: Permission denied errors
**Solution:**
1. Verify the user is authenticated
2. Check the user is a member of the household (not pending)
3. For updates/deletes, verify user is creator or owner

## Next Steps

After deploying rules:

1. ✅ Test authentication flow
2. ✅ Test household creation
3. ✅ Test joining household by code
4. ✅ Test item CRUD operations
5. ✅ Test photo uploads
6. ✅ Verify pending members can't access data
7. ✅ Verify non-members can't access household data
