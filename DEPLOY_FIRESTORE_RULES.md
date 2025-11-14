# Deploy Updated Firestore Rules & Indexes

## The Issue
You're getting errors because:
1. **"user does not have permission"** - Firebase security rules need to be deployed
2. **"query requires an index"** - Firestore indexes need to be deployed

Both the rules file and indexes file on your computer need to be deployed to Firebase.

## Quick Fix - Deploy via Firebase Console (Easiest)

### Step 1: Deploy Security Rules

1. **Open Firebase Console**
   - Go to: https://console.firebase.google.com/
   - Select your project

2. **Navigate to Firestore Rules**
   - Click "Firestore Database" in left sidebar
   - Click "Rules" tab at the top

3. **Copy the Updated Rules**
   - Open the file: `/Users/gustafeden/gustaf/OurArchive/firebase/firestore.rules`
   - Copy ALL the contents

4. **Paste and Publish**
   - Paste into the Firebase Console editor
   - Click "Publish" button

### Step 2: Create Indexes (Use Error Link - EASIEST!)

**The error message includes a direct link to create the index!**

When you see "query requires an index", the error message will have a link like:
```
https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes?create_composite=...
```

1. **Click the link in the error message**
2. **Click "Create Index"** button
3. **Wait 2-5 minutes** for index to build
4. **Try the app again**

### Step 2 Alternative: Manually Create Indexes

If you don't see the link, or prefer to do it manually:

1. **Navigate to Indexes**
   - In Firebase Console, click "Firestore Database"
   - Click "Indexes" tab at the top

2. **Click "Add Index"**

3. **For Top-Level Containers (Rooms):**
   - Collection ID: `containers`
   - Fields:
     - `householdId` - Ascending
     - `parentId` - Ascending
     - `sortOrder` - Ascending
     - `createdAt` - Ascending
   - Query scope: Collection
   - Click "Create"

4. **For Child Containers (Shelves, Boxes, etc):**
   - Collection ID: `containers`
   - Fields:
     - `parentId` - Ascending
     - `sortOrder` - Ascending
     - `createdAt` - Ascending
   - Query scope: Collection
   - Click "Create"

5. **Wait for indexes to build** (2-5 minutes each)

6. **Done!**
   - Try the app again

---

## Option 2: Deploy via Firebase CLI (If you have it installed)

```bash
cd /Users/gustafeden/gustaf/OurArchive

# Deploy rules and indexes together (RECOMMENDED)
firebase deploy --only firestore

# Or deploy just the rules
firebase deploy --only firestore:rules

# Or deploy just the indexes
firebase deploy --only firestore:indexes

# Or deploy everything
firebase deploy
```

**Note:** Indexes take 2-5 minutes to build even via CLI!

---

## What Was Added to the Rules

The new rules include support for the `containers` collection:

```javascript
// Containers collection (rooms, shelves, boxes, fridges, etc.)
match /containers/{containerId} {
  allow create: if request.auth != null && isMemberOfHousehold(request.resource.data.householdId);
  allow read: if request.auth != null && isMemberOfHousehold(resource.data.householdId);
  allow update: if request.auth != null && isMemberOfHousehold(resource.data.householdId);
  allow delete: if request.auth != null && isMemberOfHousehold(resource.data.householdId);
}
```

This allows authenticated users who are members of a household to:
- ✅ Create containers in their households
- ✅ Read containers they have access to
- ✅ Update containers in their households
- ✅ Delete containers in their households

---

## Verify It Worked

After deploying:

1. Restart your app
2. Try to tap "Organize" icon
3. Try to create a room
4. Should work without permission errors!

---

## Troubleshooting

**Still getting errors?**
- Make sure you deployed to the correct Firebase project
- Check Firebase Console → Firestore → Rules tab to verify rules are there
- Wait 30 seconds after publishing (propagation time)
- Completely restart your app (not just hot reload)

**Need to rollback?**
- Firebase Console → Firestore → Rules tab
- Click "History"
- Select previous version and restore
