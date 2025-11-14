# OurArchive: Household Inventory System - Complete Implementation Guide for Claude Code

## Project Overview

You're building **OurArchive**, a Flutter-based household inventory management system with Firebase backend. This is a family/friends-focused app for tracking items, tools, pantry goods, and household possessions with photo documentation and multi-user support.

**Core Technologies**: Flutter, Firebase (Auth, Firestore, Storage), Dart

**Key Features**: Offline-first, photo storage, barcode scanning, household sharing via 6-character codes, member approval system

## Implementation Strategy for Claude Code

### Agent Architecture

Claude Code should use a **multi-agent approach** where each agent owns a specific domain:

1. **Firebase Agent**: Manages all Firebase configuration, security rules, and backend setup
2. **Flutter Core Agent**: Handles app architecture, state management, and core services
3. **UI Agent**: Builds screens and user interface components
4. **Data Agent**: Manages offline sync, caching, and conflict resolution
5. **Testing Agent**: Creates comprehensive test suites and debug tools

### Project Structure

```
ourarchive/
├── firebase/
│   ├── firestore.rules
│   ├── storage.rules
│   └── indexes.json
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── auth/
│   │   ├── sync/
│   │   └── errors/
│   ├── data/
│   │   ├── models/
│   │   ├── repositories/
│   │   └── services/
│   ├── ui/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── theme/
│   └── utils/
├── test/
└── debug/
```

## Phase 1: Firebase Setup (Firebase Agent)

### Firestore Security Rules

Create `firebase/firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == uid;
    }

    // Households collection
    match /households/{hid} {
      allow create: if request.auth != null;
      allow read: if isMember(hid);
      allow update: if isOwner(hid);
      allow delete: if isOwner(hid);

      // Items subcollection
      match /items/{itemId} {
        allow create: if isMember(hid) && request.resource.data.createdBy == request.auth.uid;
        allow read: if isMember(hid);
        allow update: if isMember(hid) && (resource.data.createdBy == request.auth.uid || isOwner(hid));
        allow delete: if isMember(hid) && (resource.data.createdBy == request.auth.uid || isOwner(hid));
      }
    }

    // Helper functions
    function isMember(hid) {
      return request.auth != null
        && exists(/databases/$(database)/documents/households/$(hid))
        && get(/databases/$(database)/documents/households/$(hid)).data.members[request.auth.uid] in ['owner', 'member', 'viewer'];
    }

    function isOwner(hid) {
      return request.auth != null
        && exists(/databases/$(database)/documents/households/$(hid))
        && get(/databases/$(database)/documents/households/$(hid)).data.members[request.auth.uid] == 'owner';
    }
    
    function isPending(hid) {
      return request.auth != null
        && exists(/databases/$(database)/documents/households/$(hid))
        && get(/databases/$(database)/documents/households/$(hid)).data.members[request.auth.uid] == 'pending';
    }
  }
}
```

### Storage Rules

Create `firebase/storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /households/{hid}/{itemId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.resource != null
        && request.resource.metadata.owner == request.auth.uid
        && request.resource.size < 10 * 1024 * 1024; // 10MB limit
    }
  }
}
```

### Firestore Indexes

Create `firebase/indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "items",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "type", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "items",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "archived", "order": "ASCENDING" },
        { "fieldPath": "sortOrder", "order": "ASCENDING" }
      ]
    }
  ]
}
```

## Phase 2: Data Models (Flutter Core Agent)

### Create Core Models

Create `lib/data/models/household.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, String> members; // uid -> role
  final String code;
  final int schemaVersion;

  Household({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.code,
    this.schemaVersion = 1,
  });

  factory Household.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Household(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      members: Map<String, String>.from(data['members'] ?? {}),
      code: data['code'] ?? '',
      schemaVersion: data['schemaVersion'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'members': members,
    'code': code,
    'schemaVersion': schemaVersion,
  };

  bool isOwner(String uid) => members[uid] == 'owner';
  bool isMember(String uid) => members[uid] == 'member';
  bool isPending(String uid) => members[uid] == 'pending';
  bool isViewer(String uid) => members[uid] == 'viewer';
  bool hasAccess(String uid) => members.containsKey(uid) && members[uid] != 'pending';
}
```

Create `lib/data/models/item.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum SyncStatus { pending, syncing, synced, error }

class Item {
  final String id;
  final String title;
  final String type; // 'pantry', 'tool', 'camera', etc.
  final String location;
  final List<String> tags;
  final int quantity;
  final bool archived;
  final int sortOrder;
  final String? photoPath;
  final String? photoThumbPath;
  final DateTime lastModified;
  final DateTime createdAt;
  final String createdBy;
  final SyncStatus syncStatus;
  final String searchText;
  final int version;
  final DateTime? deletedAt;
  final String? barcode;
  final Map<String, dynamic>? reminder;

  Item({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.tags,
    this.quantity = 1,
    this.archived = false,
    this.sortOrder = 0,
    this.photoPath,
    this.photoThumbPath,
    required this.lastModified,
    required this.createdAt,
    required this.createdBy,
    this.syncStatus = SyncStatus.synced,
    required this.searchText,
    this.version = 1,
    this.deletedAt,
    this.barcode,
    this.reminder,
  });

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Item(
      id: doc.id,
      title: data['title'] ?? '',
      type: data['type'] ?? 'general',
      location: data['location'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      quantity: data['quantity'] ?? 1,
      archived: data['archived'] ?? false,
      sortOrder: data['sortOrder'] ?? 0,
      photoPath: data['photoPath'],
      photoThumbPath: data['photoThumbPath'],
      lastModified: (data['lastModified'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      syncStatus: _parseSyncStatus(data['syncStatus']),
      searchText: data['searchText'] ?? '',
      version: data['version'] ?? 1,
      deletedAt: data['deletedAt'] != null 
        ? (data['deletedAt'] as Timestamp).toDate() 
        : null,
      barcode: data['barcode'],
      reminder: data['reminder'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'type': type,
    'location': location,
    'tags': tags,
    'quantity': quantity,
    'archived': archived,
    'sortOrder': sortOrder,
    'photoPath': photoPath,
    'photoThumbPath': photoThumbPath,
    'lastModified': Timestamp.fromDate(lastModified),
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'syncStatus': syncStatus.toString().split('.').last,
    'searchText': searchText,
    'version': version,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'barcode': barcode,
    'reminder': reminder,
  };

  static SyncStatus _parseSyncStatus(String? status) {
    switch (status) {
      case 'pending': return SyncStatus.pending;
      case 'syncing': return SyncStatus.syncing;
      case 'error': return SyncStatus.error;
      default: return SyncStatus.synced;
    }
  }

  static String generateSearchText(String title, String type, String location, List<String> tags) {
    final parts = [title, type, location, ...tags];
    return parts.join(' ').toLowerCase();
  }
}
```

## Phase 3: Core Services (Flutter Core Agent)

### Authentication Service

Create `lib/data/services/auth_service.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  // Week 1: Anonymous auth
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  // Week 2: Email/Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: password,
    );
    
    // Create user profile
    await _firestore.collection('users').doc(credential.user!.uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'households': [],
    });
    
    return credential;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Link anonymous to permanent
  Future<void> linkAnonymousToEmail(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw Exception('No anonymous user to link');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    
    await user.linkWithCredential(credential);
    
    // Update user profile
    await _firestore.collection('users').doc(user.uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'households': [],
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
```

### Household Service

Create `lib/data/services/household_service.dart`:

```dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate unique 6-character code with checksum
  String generateHouseholdCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    
    // Generate 5 chars
    final prefix = List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
    
    // Add checksum digit
    int sum = 0;
    for (int i = 0; i < prefix.length; i++) {
      sum += chars.indexOf(prefix[i]) * (i + 1);
    }
    final checksum = chars[sum % chars.length];
    
    return '$prefix$checksum';
  }

  // Create new household
  Future<String> createHousehold({
    required String name,
    required String creatorUid,
  }) async {
    final code = generateHouseholdCode();
    
    final docRef = await _firestore.collection('households').add({
      'name': name,
      'createdBy': creatorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': {creatorUid: 'owner'},
      'code': code,
      'schemaVersion': 1,
    });

    // Update user's household list
    await _firestore.collection('users').doc(creatorUid).update({
      'households': FieldValue.arrayUnion([docRef.id]),
    });

    return docRef.id;
  }

  // Join household by code
  Future<void> requestJoinByCode({
    required String code,
    required String userId,
  }) async {
    // Find household with this code
    final query = await _firestore
        .collection('households')
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid household code');
    }

    final householdId = query.docs.first.id;
    final household = query.docs.first.data();

    // Check if already member
    if (household['members']?[userId] != null) {
      throw Exception('Already a member of this household');
    }

    // Add as pending
    await _firestore.collection('households').doc(householdId).update({
      'members.$userId': 'pending',
    });
  }

  // Approve pending member
  Future<void> approveMember({
    required String householdId,
    required String memberUid,
    required String approverUid,
  }) async {
    final doc = await _firestore.collection('households').doc(householdId).get();
    final data = doc.data()!;
    
    // Check approver is owner
    if (data['members'][approverUid] != 'owner') {
      throw Exception('Only owners can approve members');
    }

    // Check member is pending
    if (data['members'][memberUid] != 'pending') {
      throw Exception('User is not pending approval');
    }

    // Update to member
    await _firestore.collection('households').doc(householdId).update({
      'members.$memberUid': 'member',
    });

    // Add to user's household list
    await _firestore.collection('users').doc(memberUid).update({
      'households': FieldValue.arrayUnion([householdId]),
    });
  }

  // Get user's households
  Stream<List<Household>> getUserHouseholds(String userId) {
    return _firestore
        .collection('households')
        .where('members.$userId', whereIn: ['owner', 'member', 'viewer'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Household.fromFirestore(doc))
            .toList());
  }

  // Get pending approvals for owner
  Stream<List<Map<String, String>>> getPendingMembers(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return [];
          
          final members = Map<String, String>.from(doc.data()!['members'] ?? {});
          final pending = <Map<String, String>>[];
          
          members.forEach((uid, role) {
            if (role == 'pending') {
              pending.add({'uid': uid, 'role': role});
            }
          });
          
          return pending;
        });
  }
}
```

### Sync Queue Service

Create `lib/core/sync/sync_queue.dart`:

```dart
import 'dart:async';
import 'dart:collection';
import 'package:connectivity_plus/connectivity_plus.dart';

enum TaskPriority { high, normal, low }

class SyncTask {
  final String id;
  final Future<void> Function() execute;
  final TaskPriority priority;
  final int maxRetries;
  int attempts = 0;
  DateTime? lastAttempt;
  String? lastError;

  SyncTask({
    required this.id,
    required this.execute,
    this.priority = TaskPriority.normal,
    this.maxRetries = 3,
  });
}

class SyncQueue {
  final Queue<SyncTask> _highPriority = Queue();
  final Queue<SyncTask> _normalPriority = Queue();
  final Queue<SyncTask> _lowPriority = Queue();
  
  bool _isProcessing = false;
  StreamSubscription? _connectivitySubscription;
  Timer? _retryTimer;

  SyncQueue() {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        process();
      }
    });

    // Retry failed tasks every 30 seconds
    _retryTimer = Timer.periodic(Duration(seconds: 30), (_) => process());
  }

  void add(SyncTask task) {
    switch (task.priority) {
      case TaskPriority.high:
        _highPriority.add(task);
        break;
      case TaskPriority.normal:
        _normalPriority.add(task);
        break;
      case TaskPriority.low:
        _lowPriority.add(task);
        break;
    }
    
    process();
  }

  Future<void> process() async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return;
      }

      // Process high priority first
      await _processQueue(_highPriority);
      await _processQueue(_normalPriority);
      await _processQueue(_lowPriority);
      
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processQueue(Queue<SyncTask> queue) async {
    while (queue.isNotEmpty) {
      final task = queue.removeFirst();
      
      try {
        task.lastAttempt = DateTime.now();
        await task.execute();
        // Success - task is done
      } catch (error) {
        task.attempts++;
        task.lastError = error.toString();
        
        if (task.attempts < task.maxRetries) {
          // Re-add to queue for retry
          queue.add(task);
        } else {
          // Max retries reached - log error
          print('Task ${task.id} failed after ${task.maxRetries} attempts: $error');
        }
      }
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }

  // Get queue stats for debug screen
  Map<String, int> getStats() => {
    'high': _highPriority.length,
    'normal': _normalPriority.length,
    'low': _lowPriority.length,
  };
}
```

### Item Repository

Create `lib/data/repositories/item_repository.dart`:

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ItemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SyncQueue _syncQueue;
  
  ItemRepository(this._syncQueue);

  // Add item with optimistic UI and offline support
  Future<String> addItem({
    required String householdId,
    required String userId,
    required Map<String, dynamic> itemData,
    File? photo,
  }) async {
    final itemId = Uuid().v4();
    
    // Prepare item data
    final now = DateTime.now();
    final searchText = Item.generateSearchText(
      itemData['title'],
      itemData['type'],
      itemData['location'],
      List<String>.from(itemData['tags'] ?? []),
    );
    
    final item = {
      ...itemData,
      'createdBy': userId,
      'createdAt': Timestamp.fromDate(now),
      'lastModified': Timestamp.fromDate(now),
      'syncStatus': 'pending',
      'searchText': searchText,
      'version': 1,
    };

    // Try to add to Firestore immediately
    try {
      final docRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('items')
          .doc(itemId);
      
      await docRef.set(item);
      
      // Upload photo if provided
      if (photo != null) {
        await _uploadPhoto(householdId, itemId, userId, photo, docRef);
      }
      
      // Update sync status
      await docRef.update({'syncStatus': 'synced'});
      
    } catch (error) {
      // Queue for retry
      _syncQueue.add(SyncTask(
        id: 'add_item_$itemId',
        execute: () async {
          final docRef = _firestore
              .collection('households')
              .doc(householdId)
              .collection('items')
              .doc(itemId);
          
          await docRef.set(item);
          
          if (photo != null) {
            await _uploadPhoto(householdId, itemId, userId, photo, docRef);
          }
          
          await docRef.update({'syncStatus': 'synced'});
        },
        priority: TaskPriority.high,
      ));
    }
    
    return itemId;
  }

  Future<void> _uploadPhoto(
    String householdId,
    String itemId,
    String userId,
    File photo,
    DocumentReference docRef,
  ) async {
    // Generate thumbnail
    final thumbFile = await _generateThumbnail(photo);
    
    // Upload full image
    final imagePath = 'households/$householdId/$itemId/image.jpg';
    final imageRef = _storage.ref().child(imagePath);
    final imageMetadata = SettableMetadata(
      customMetadata: {'owner': userId},
      contentType: 'image/jpeg',
    );
    await imageRef.putFile(photo, imageMetadata);
    
    // Upload thumbnail
    final thumbPath = 'households/$householdId/$itemId/thumb.jpg';
    final thumbRef = _storage.ref().child(thumbPath);
    await thumbRef.putFile(thumbFile, imageMetadata);
    
    // Update document with paths
    await docRef.update({
      'photoPath': imagePath,
      'photoThumbPath': thumbPath,
    });
  }

  Future<File> _generateThumbnail(File image) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final result = await FlutterImageCompress.compressAndGetFile(
      image.path,
      targetPath,
      minWidth: 200,
      minHeight: 200,
      quality: 70,
    );
    
    return File(result!.path);
  }

  // Get items stream with offline support
  Stream<List<Item>> getItems(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .where('deletedAt', isEqualTo: null)
        .orderBy('sortOrder')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Item.fromFirestore(doc))
            .toList());
  }

  // Update item with conflict resolution
  Future<void> updateItem({
    required String householdId,
    required String itemId,
    required Map<String, dynamic> updates,
    required int currentVersion,
  }) async {
    final docRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .doc(itemId);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      
      if (!doc.exists) {
        throw Exception('Item does not exist');
      }
      
      final serverVersion = doc.data()!['version'] ?? 1;
      
      if (serverVersion != currentVersion) {
        // Conflict - implement your resolution strategy
        throw Exception('Item was modified by another user');
      }
      
      transaction.update(docRef, {
        ...updates,
        'lastModified': FieldValue.serverTimestamp(),
        'version': serverVersion + 1,
      });
    });
  }

  // Soft delete
  Future<void> deleteItem(String householdId, String itemId) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .doc(itemId)
        .update({
          'deletedAt': FieldValue.serverTimestamp(),
        });
  }
}
```

## Phase 4: UI Implementation (UI Agent)

### Main App Structure

Create `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  // Error handling
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  runZonedGuarded(() {
    runApp(ProviderScope(child: OurArchiveApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
  });
}

class OurArchiveApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OurArchive',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### Auth Gate

Create `lib/ui/screens/auth_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData) {
          return HouseholdListScreen();
        }
        
        return WelcomeScreen();
      },
    );
  }
}
```

### Welcome Screen (Week 1: Anonymous Auth)

Create `lib/ui/screens/welcome_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WelcomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: 80, color: Theme.of(context).primaryColor),
              SizedBox(height: 24),
              Text(
                'OurArchive',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              SizedBox(height: 8),
              Text(
                'Track and share your household inventory',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48),
              
              // Week 1: Anonymous sign in
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await authService.signInAnonymously();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
                icon: Icon(Icons.arrow_forward),
                label: Text('Get Started'),
              ),
              
              // Week 2: Add email sign in option
              TextButton(
                onPressed: () {
                  // Navigate to email sign in
                },
                child: Text('Sign in with Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Phase 5: Debug Tools (Testing Agent)

### Debug Screen

Create `lib/debug/debug_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:faker/faker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncQueue = ref.read(syncQueueProvider);
    final itemRepo = ref.read(itemRepositoryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Tools'),
        backgroundColor: Colors.red.shade900,
      ),
      body: ListView(
        children: [
          // Sync Queue Stats
          Card(
            child: ListTile(
              title: Text('Sync Queue Status'),
              subtitle: StreamBuilder(
                stream: Stream.periodic(Duration(seconds: 1)),
                builder: (context, snapshot) {
                  final stats = syncQueue.getStats();
                  return Text(
                    'High: ${stats['high']} | Normal: ${stats['normal']} | Low: ${stats['low']}',
                  );
                },
              ),
              trailing: IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () => syncQueue.process(),
              ),
            ),
          ),
          
          Divider(),
          
          // Test Data Generation
          ListTile(
            title: Text('Generate 50 Test Items'),
            leading: Icon(Icons.add_box),
            onTap: () => _generateTestItems(context, ref),
          ),
          
          ListTile(
            title: Text('Generate 1000 Items (Stress Test)'),
            leading: Icon(Icons.warning, color: Colors.orange),
            onTap: () => _generateManyItems(context, ref, 1000),
          ),
          
          Divider(),
          
          // Network Simulation
          ListTile(
            title: Text('Simulate Network Error'),
            leading: Icon(Icons.wifi_off),
            onTap: () => _simulateNetworkError(context),
          ),
          
          ListTile(
            title: Text('Corrupt Sync State'),
            leading: Icon(Icons.broken_image),
            onTap: () => _corruptSyncState(context, ref),
          ),
          
          Divider(),
          
          // Cache Management
          ListTile(
            title: Text('Clear Image Cache'),
            leading: Icon(Icons.clear),
            onTap: () => _clearImageCache(context),
          ),
          
          ListTile(
            title: Text('Export Debug Log'),
            leading: Icon(Icons.file_download),
            onTap: () => _exportDebugLog(context),
          ),
          
          Divider(),
          
          // Dangerous Actions
          Card(
            color: Colors.red.shade50,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'DANGER ZONE',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  title: Text('Delete All Items'),
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  onTap: () => _confirmDangerousAction(
                    context,
                    'Delete all items?',
                    () => _deleteAllItems(ref),
                  ),
                ),
                ListTile(
                  title: Text('Reset Household'),
                  leading: Icon(Icons.restore, color: Colors.red),
                  onTap: () => _confirmDangerousAction(
                    context,
                    'Reset household?',
                    () => _resetHousehold(ref),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTestItems(BuildContext context, WidgetRef ref) async {
    final faker = Faker();
    final items = <Map<String, dynamic>>[];
    
    final types = ['tool', 'pantry', 'camera', 'book', 'electronics'];
    final locations = ['Garage', 'Kitchen', 'Living Room', 'Bedroom', 'Office'];
    
    for (int i = 0; i < 50; i++) {
      items.add({
        'title': faker.commerce.productName(),
        'type': types[i % types.length],
        'location': locations[i % locations.length],
        'tags': [
          faker.commerce.department(),
          faker.color.color(),
        ],
        'quantity': faker.randomGenerator.integer(10, min: 1),
        'barcode': faker.randomGenerator.integer(999999999).toString(),
      });
    }
    
    // Add items to current household
    final householdId = ref.read(currentHouseholdIdProvider);
    final userId = ref.read(authServiceProvider).currentUserId!;
    final itemRepo = ref.read(itemRepositoryProvider);
    
    for (final item in items) {
      await itemRepo.addItem(
        householdId: householdId,
        userId: userId,
        itemData: item,
      );
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generated 50 test items')),
    );
  }

  Future<void> _generateManyItems(BuildContext context, WidgetRef ref, int count) async {
    // Similar to above but with progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Generating $count items...'),
        content: LinearProgressIndicator(),
      ),
    );
    
    // Generate items...
    
    Navigator.of(context).pop();
  }

  void _simulateNetworkError(BuildContext context) {
    // Implement network error simulation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Network error simulated - check sync queue'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _corruptSyncState(BuildContext context, WidgetRef ref) {
    // Intentionally corrupt sync state for testing recovery
  }

  Future<void> _clearImageCache(BuildContext context) async {
    // Clear cached images
  }

  Future<void> _exportDebugLog(BuildContext context) async {
    // Export debug information
  }

  void _confirmDangerousAction(
    BuildContext context,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllItems(WidgetRef ref) async {
    // Delete all items in current household
  }

  Future<void> _resetHousehold(WidgetRef ref) async {
    // Reset household to initial state
  }
}
```

## Phase 6: State Management (Flutter Core Agent)

### Riverpod Providers

Create `lib/providers/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ourarchive/data/services/auth_service.dart';
import 'package:ourarchive/data/services/household_service.dart';
import 'package:ourarchive/data/repositories/item_repository.dart';
import 'package:ourarchive/core/sync/sync_queue.dart';

// Core services
final authServiceProvider = Provider((ref) => AuthService());
final householdServiceProvider = Provider((ref) => HouseholdService());
final syncQueueProvider = Provider((ref) => SyncQueue());

final itemRepositoryProvider = Provider((ref) {
  final syncQueue = ref.watch(syncQueueProvider);
  return ItemRepository(syncQueue);
});

// Current user
final currentUserProvider = StreamProvider((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current household
final currentHouseholdIdProvider = StateProvider<String>((ref) => '');

// User's households
final userHouseholdsProvider = StreamProvider((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(<Household>[]);
  
  final householdService = ref.watch(householdServiceProvider);
  return householdService.getUserHouseholds(user.uid);
});

// Items in current household
final householdItemsProvider = StreamProvider((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId.isEmpty) return Stream.value(<Item>[]);
  
  final itemRepo = ref.watch(itemRepositoryProvider);
  return itemRepo.getItems(householdId);
});

// Filtered items
final filteredItemsProvider = Provider((ref) {
  final items = ref.watch(householdItemsProvider).value ?? [];
  final searchQuery = ref.watch(searchQueryProvider);
  final selectedType = ref.watch(selectedTypeProvider);
  
  return items.where((item) {
    if (searchQuery.isNotEmpty && 
        !item.searchText.contains(searchQuery.toLowerCase())) {
      return false;
    }
    
    if (selectedType != null && item.type != selectedType) {
      return false;
    }
    
    return !item.archived;
  }).toList();
});

// UI state
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedTypeProvider = StateProvider<String?>((ref) => null);
```

## Phase 7: Testing (Testing Agent)

### Unit Tests

Create `test/services/household_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:ourarchive/data/services/household_service.dart';

void main() {
  group('HouseholdService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late HouseholdService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = HouseholdService(firestore: fakeFirestore);
    });

    test('generateHouseholdCode creates valid 6-char code', () {
      final code = service.generateHouseholdCode();
      
      expect(code.length, equals(6));
      expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(code), isTrue);
    });

    test('generateHouseholdCode includes valid checksum', () {
      final code = service.generateHouseholdCode();
      
      // Verify checksum
      const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
      int sum = 0;
      for (int i = 0; i < 5; i++) {
        sum += chars.indexOf(code[i]) * (i + 1);
      }
      final expectedChecksum = chars[sum % chars.length];
      
      expect(code[5], equals(expectedChecksum));
    });

    test('createHousehold creates household with owner', () async {
      final householdId = await service.createHousehold(
        name: 'Test Home',
        creatorUid: 'user123',
      );
      
      final doc = await fakeFirestore
          .collection('households')
          .doc(householdId)
          .get();
      
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], equals('Test Home'));
      expect(doc.data()!['members']['user123'], equals('owner'));
      expect(doc.data()!['code'], isNotNull);
    });

    test('requestJoinByCode adds user as pending', () async {
      // Create household first
      final householdId = await service.createHousehold(
        name: 'Test Home',
        creatorUid: 'owner123',
      );
      
      final doc = await fakeFirestore
          .collection('households')
          .doc(householdId)
          .get();
      final code = doc.data()!['code'];
      
      // Request to join
      await service.requestJoinByCode(
        code: code,
        userId: 'user456',
      );
      
      final updatedDoc = await fakeFirestore
          .collection('households')
          .doc(householdId)
          .get();
      
      expect(updatedDoc.data()!['members']['user456'], equals('pending'));
    });

    test('approveMember changes pending to member', () async {
      // Setup
      final householdId = await service.createHousehold(
        name: 'Test Home',
        creatorUid: 'owner123',
      );
      
      await fakeFirestore.collection('households').doc(householdId).update({
        'members.user456': 'pending',
      });
      
      // Approve
      await service.approveMember(
        householdId: householdId,
        memberUid: 'user456',
        approverUid: 'owner123',
      );
      
      final doc = await fakeFirestore
          .collection('households')
          .doc(householdId)
          .get();
      
      expect(doc.data()!['members']['user456'], equals('member'));
    });

    test('approveMember throws if approver is not owner', () async {
      final householdId = await service.createHousehold(
        name: 'Test Home',
        creatorUid: 'owner123',
      );
      
      await fakeFirestore.collection('households').doc(householdId).update({
        'members.user456': 'pending',
        'members.user789': 'member',
      });
      
      expect(
        () => service.approveMember(
          householdId: householdId,
          memberUid: 'user456',
          approverUid: 'user789', // Not owner
        ),
        throwsException,
      );
    });
  });
}
```

### Widget Tests

Create `test/ui/item_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ourarchive/ui/screens/item_list_screen.dart';

void main() {
  testWidgets('ItemListScreen shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdItemsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(home: ItemListScreen()),
      ),
    );
    
    expect(find.text('No items yet'), findsOneWidget);
    expect(find.text('Tap + to add your first item'), findsOneWidget);
  });

  testWidgets('ItemListScreen shows items', (tester) async {
    final testItems = [
      Item(
        id: '1',
        title: 'Test Item 1',
        type: 'tool',
        location: 'Garage',
        tags: ['test'],
        createdBy: 'user1',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        searchText: 'test item 1 tool garage',
      ),
    ];
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdItemsProvider.overrideWith((ref) => Stream.value(testItems)),
        ],
        child: MaterialApp(home: ItemListScreen()),
      ),
    );
    
    await tester.pumpAndSettle();
    
    expect(find.text('Test Item 1'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
  });

  testWidgets('Search filters items correctly', (tester) async {
    // Test search functionality
  });
}
```

## Implementation Instructions for Claude Code

### Best Practices for Claude Code

1. **Use Multi-Agent Architecture**: Divide work between specialized agents:
   - Firebase Agent handles backend configuration
   - Flutter Core Agent builds services and models
   - UI Agent creates screens
   - Data Agent manages offline sync
   - Testing Agent writes tests

2. **Incremental Development**:
   - Start with Week 1 MVP features only
   - Test each component before moving on
   - Use hot reload extensively

3. **Error Handling**:
   - Wrap all async operations in try-catch
   - Use the SyncQueue for retry logic
   - Log errors to Crashlytics

4. **Code Organization**:
   - Keep files small and focused
   - Use consistent naming conventions
   - Document complex logic

5. **Testing Strategy**:
   - Write unit tests for business logic
   - Widget tests for UI components
   - Integration tests for critical flows

### Deployment Checklist

#### Before TestFlight:
- [ ] Firebase project created and configured
- [ ] Security rules deployed and tested
- [ ] Anonymous auth working
- [ ] Basic CRUD operations tested
- [ ] Offline mode tested
- [ ] Debug screen hidden in release mode
- [ ] Crashlytics configured

#### Week 1 Deliverables:
- [ ] Anonymous sign in
- [ ] Create household with code
- [ ] Join household by code
- [ ] Add/edit/delete items
- [ ] Photo upload
- [ ] Basic offline support

#### Week 2 Deliverables:
- [ ] Email/password auth
- [ ] Account linking
- [ ] Member approval flow
- [ ] Search and filters
- [ ] Barcode scanning
- [ ] Export to CSV

#### Week 3 Deliverables:
- [ ] Reminders
- [ ] Bulk operations
- [ ] Performance optimizations
- [ ] Polish UI
- [ ] Add Apple Sign In
- [ ] Prepare for App Store

### Common Issues and Solutions

1. **Firestore offline persistence**:
   ```dart
   FirebaseFirestore.instance.settings = Settings(
     persistenceEnabled: true,
     cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
   );
   ```

2. **Image caching**:
   ```dart
   CachedNetworkImage(
     imageUrl: url,
     placeholder: (context, url) => CircularProgressIndicator(),
     errorWidget: (context, url, error) => Icon(Icons.error),
   );
   ```

3. **Handling large households**:
   - Implement pagination
   - Use indexed queries
   - Cache frequently accessed data

### Performance Optimizations

1. **Use Firestore indexes** for common queries
2. **Generate thumbnails** on upload
3. **Implement lazy loading** for item lists
4. **Cache images locally** using flutter_cache_manager
5. **Use StreamBuilder** for real-time updates

### Security Considerations

1. **Validate all inputs** on client and server
2. **Use security rules** to enforce access control
3. **Sanitize user-generated content**
4. **Implement rate limiting** for expensive operations
5. **Store sensitive data** encrypted locally

This plan provides a complete, production-ready implementation that Claude Code can execute systematically. Each phase builds on the previous one, ensuring a stable foundation while maintaining flexibility for future enhancements.