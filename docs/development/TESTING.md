# Database & Security Rules Testing Plan

## Overview
This document outlines the testing strategy to verify that Firestore database and security rules work correctly for the OurArchive app.

---

## 1. Manual Testing Checklist

### Authentication & User Management
- [ ] Sign up new user successfully
- [ ] Sign in with existing user
- [ ] Sign out and verify no data access
- [ ] Password reset flow works

### Household Management
- [ ] Create a new household (user becomes owner)
- [ ] View household list
- [ ] Join household by code (as new member)
- [ ] Approve pending member (as owner)
- [ ] Delete household (as owner only)
- [ ] Attempt to delete household (as non-owner, should fail)

### Container Management (Nested Hierarchy)
- [ ] Create top-level room
- [ ] Create child container (shelf in room)
- [ ] Create grandchild container (box on shelf)
- [ ] View container hierarchy correctly
- [ ] Delete empty container
- [ ] Attempt to delete container with items (should fail)
- [ ] Move container to different parent

### Item Management
- [ ] Add item to household
- [ ] Add item to specific container
- [ ] View all household items
- [ ] View items in specific container
- [ ] Update item details
- [ ] Move item between containers
- [ ] Soft delete item
- [ ] Search/filter items

### Permission Testing
- [ ] User A creates household
- [ ] User B joins household as member
- [ ] User B can view items
- [ ] User B can create items
- [ ] User B can update their own items
- [ ] User B cannot delete household (owner-only)
- [ ] User C (not a member) cannot view household data
- [ ] Sign out User A, verify User A cannot access data

---

## 2. Firebase Rules Simulator Testing

Use Firebase Console → Firestore → Rules → Simulator to test:

### Household Rules Tests

**Test 1: Create Household**
```
Operation: create
Path: /households/test-hid-123
Auth: Authenticated (UID: test-user-1)
Data: {
  "name": "Test Home",
  "createdBy": "test-user-1",
  "members": {
    "test-user-1": "owner"
  }
}
Expected: ALLOW
```

**Test 2: Read Household as Member**
```
Operation: get
Path: /households/XVNti0fUwyADpQLZ5f1Y
Auth: Authenticated (UID: 7gKizGf14jbphpxTftSlIbK6D3f2)
Expected: ALLOW (user is in members map)
```

**Test 3: Read Household as Non-Member**
```
Operation: get
Path: /households/XVNti0fUwyADpQLZ5f1Y
Auth: Authenticated (UID: fake-user-123)
Expected: DENY
```

### Container Rules Tests

**Test 4: List Top-Level Containers**
```
Operation: list
Path: /containers
Query: householdId == "XVNti0fUwyADpQLZ5f1Y" && parentId == null
Auth: Authenticated (UID: 7gKizGf14jbphpxTftSlIbK6D3f2)
Expected: ALLOW
```

**Test 5: List Child Containers**
```
Operation: list
Path: /containers
Query: householdId == "XVNti0fUwyADpQLZ5f1Y" && parentId == "nxCwbjjdNly2gOCWjPnI"
Auth: Authenticated (UID: 7gKizGf14jbphpxTftSlIbK6D3f2)
Expected: ALLOW
```

**Test 6: Create Container (Non-Member)**
```
Operation: create
Path: /containers/new-container-id
Auth: Authenticated (UID: fake-user-123)
Data: {
  "householdId": "XVNti0fUwyADpQLZ5f1Y",
  "name": "Hacker Room",
  "containerType": "room",
  "createdBy": "fake-user-123"
}
Expected: DENY
```

### Item Rules Tests

**Test 7: List Items in Household**
```
Operation: list
Path: /households/XVNti0fUwyADpQLZ5f1Y/items
Auth: Authenticated (UID: 7gKizGf14jbphpxTftSlIbK6D3f2)
Expected: ALLOW
```

**Test 8: Create Item as Member**
```
Operation: create
Path: /households/XVNti0fUwyADpQLZ5f1Y/items/new-item-id
Auth: Authenticated (UID: 7gKizGf14jbphpxTftSlIbK6D3f2)
Data: {
  "title": "Test Book",
  "createdBy": "7gKizGf14jbphpxTftSlIbK6D3f2",
  "createdAt": <timestamp>
}
Expected: ALLOW
```

**Test 9: Read Items (Non-Member)**
```
Operation: list
Path: /households/XVNti0fUwyADpQLZ5f1Y/items
Auth: Authenticated (UID: fake-user-123)
Expected: DENY
```

---

## 3. Automated Testing with Firestore Emulator

### Setup
```bash
# Install Firebase emulator
npm install -g firebase-tools

# Initialize emulator
cd firebase
firebase init emulators
# Select Firestore

# Start emulator
firebase emulators:start --only firestore
```

### Write Test Script

Create `firebase/test/firestore.test.js`:

```javascript
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const fs = require('fs');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'ourarchive-test',
    firestore: {
      rules: fs.readFileSync('firestore.rules', 'utf8'),
      host: 'localhost',
      port: 8080
    }
  });
});

after(async () => {
  await testEnv.cleanup();
});

describe('Household Rules', () => {
  it('allows authenticated user to create household', async () => {
    const alice = testEnv.authenticatedContext('alice');
    const household = alice.firestore().collection('households').doc('h1');

    await assertSucceeds(household.set({
      name: 'Alice Home',
      createdBy: 'alice',
      members: { alice: 'owner' }
    }));
  });

  it('allows member to read household', async () => {
    const bob = testEnv.authenticatedContext('bob');

    // Setup: Alice creates household with Bob as member
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('households').doc('h1').set({
        name: 'Alice Home',
        members: { alice: 'owner', bob: 'member' }
      });
    });

    const household = bob.firestore().collection('households').doc('h1');
    await assertSucceeds(household.get());
  });

  it('denies non-member to read household', async () => {
    const charlie = testEnv.authenticatedContext('charlie');
    const household = charlie.firestore().collection('households').doc('h1');

    await assertFails(household.get());
  });
});

describe('Container Rules', () => {
  beforeEach(async () => {
    // Setup test household
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('households').doc('h1').set({
        name: 'Test Home',
        members: { alice: 'owner' }
      });
    });
  });

  it('allows member to query containers with householdId', async () => {
    const alice = testEnv.authenticatedContext('alice');

    await assertSucceeds(
      alice.firestore()
        .collection('containers')
        .where('householdId', '==', 'h1')
        .where('parentId', '==', null)
        .get()
    );
  });

  it('denies non-member to query containers', async () => {
    const bob = testEnv.authenticatedContext('bob');

    await assertFails(
      bob.firestore()
        .collection('containers')
        .where('householdId', '==', 'h1')
        .get()
    );
  });
});

describe('Item Rules', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('households').doc('h1').set({
        name: 'Test Home',
        members: { alice: 'owner', bob: 'member' }
      });
    });
  });

  it('allows member to create item', async () => {
    const bob = testEnv.authenticatedContext('bob');

    await assertSucceeds(
      bob.firestore()
        .collection('households').doc('h1')
        .collection('items').doc('item1')
        .set({
          title: 'Test Item',
          createdBy: 'bob',
          createdAt: new Date()
        })
    );
  });

  it('allows member to list items', async () => {
    const alice = testEnv.authenticatedContext('alice');

    await assertSucceeds(
      alice.firestore()
        .collection('households').doc('h1')
        .collection('items')
        .get()
    );
  });

  it('denies non-member to list items', async () => {
    const charlie = testEnv.authenticatedContext('charlie');

    await assertFails(
      charlie.firestore()
        .collection('households').doc('h1')
        .collection('items')
        .get()
    );
  });
});
```

### Run Tests
```bash
cd firebase
npm test
```

---

## 4. Integration Testing in App

Create `our_archive/test/integration_test/firestore_integration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp();

    // Use emulator for testing
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  group('Firestore Integration Tests', () {
    test('User can create and read household', () async {
      final firestore = FirebaseFirestore.instance;

      // Create household
      final householdRef = await firestore.collection('households').add({
        'name': 'Test Home',
        'createdBy': 'test-user',
        'members': {'test-user': 'owner'},
      });

      // Read it back
      final snapshot = await householdRef.get();
      expect(snapshot.exists, true);
      expect(snapshot.data()!['name'], 'Test Home');

      // Cleanup
      await householdRef.delete();
    });

    test('Container queries include householdId', () async {
      final firestore = FirebaseFirestore.instance;

      // This should not throw permission error
      final query = firestore
          .collection('containers')
          .where('householdId', isEqualTo: 'test-household')
          .where('parentId', isEqualTo: 'test-parent');

      final snapshot = await query.get();
      expect(snapshot.docs, isNotNull);
    });
  });
}
```

Run:
```bash
fvm flutter test integration_test/firestore_integration_test.dart
```

---

## 5. Performance & Index Verification

### Check Required Indexes

Monitor Firebase Console → Firestore → Indexes for:

1. **Containers Collection**
   - Composite: `householdId` (ASC) + `parentId` (ASC) + `sortOrder` (ASC) + `createdAt` (ASC)

2. **Items Collection**
   - Single field: `createdAt` (DESC)

### Load Testing

Test with realistic data:
- 1,000 items across 50 containers
- 10 concurrent users
- Measure query response times

---

## 6. Security Best Practices Checklist

- [x] All queries include `householdId` where needed
- [x] Security rules use direct map lookups (not `.keys()`)
- [x] No compound queries without proper indexes
- [x] Helper functions avoid circular `get()` dependencies
- [x] Pending members cannot perform destructive operations
- [x] Only owners can delete households
- [x] Users can only access households they belong to

---

## 7. Production Deployment Checklist

Before deploying to production:

- [ ] Run all manual tests
- [ ] Run Firebase Rules Simulator tests
- [ ] Run automated emulator tests
- [ ] Verify all indexes are created
- [ ] Test with production-like data volume
- [ ] Test on slow network conditions
- [ ] Test offline functionality
- [ ] Monitor Firestore usage/costs for first week
- [ ] Set up Firebase monitoring alerts

---

## Next Steps

1. Implement automated tests using Firestore emulator
2. Set up CI/CD to run tests before deployment
3. Create monitoring dashboard for Firestore metrics
4. Document any new indexes needed in `firestore.indexes.json`
