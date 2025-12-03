# Portfolio Photo Management System

A guide for implementing portfolio photo management in the OurArchive Flutter app, syncing with Firebase for the portfolio website.

## Overview

**Goal**: Manage portfolio photos from the Flutter app, with changes reflecting on the portfolio website in real-time.

**Flow**:
```
Flutter App (admin) → Firebase Storage + Firestore → Portfolio Website (public)
```

**Features**:
- Create/delete photo collections
- Upload images with auto-optimization
- Auto-extract EXIF data
- Edit captions, locations, notes
- Toggle EXIF visibility per photo
- Real-time sync to portfolio website

---

## Architecture

### Firebase Storage Structure
```
portfolio/
  photos/
    {collection-slug}/
      _cover.jpg           # 600px thumbnail for grid
      {photo-id}.jpg       # 2000px optimized images
```

### Firestore Structure
```
portfolio_collections/
  {collection-id}/
    title: "Fuji 18-55"
    slug: "fuji18-55"
    description: "Photos taken with my kit lens"
    cover: "https://storage.../portfolio/photos/fuji18-55/_cover.jpg"
    order: 1
    visible: true
    createdAt: Timestamp
    updatedAt: Timestamp

portfolio_photos/
  {photo-id}/
    collectionId: "abc123"
    src: "https://storage.../portfolio/photos/fuji18-55/photo1.jpg"
    caption: "Morning light on the lens"
    location: "Stockholm, Sweden"
    notes: "My favorite shot from this session"
    showExif: true
    exif: {
      camera: "FUJIFILM X-T4"
      lens: "XF18-55mmF2.8-4 R LM OIS"
      aperture: "f/2.8"
      shutter: "1/250s"
      iso: 400
      focalLength: "55mm"
      date: "2024-03-15"
    }
    order: 1
    createdAt: Timestamp
    updatedAt: Timestamp
```

---

## Security Rules

### Firestore Rules

Add to `firebase/firestore.rules`:

```javascript
// Portfolio collections - public read, admin write
match /portfolio_collections/{collectionId} {
  allow read: if true;
  allow write: if isPortfolioAdmin();
}

// Portfolio photos - public read, admin write
match /portfolio_photos/{photoId} {
  allow read: if true;
  allow write: if isPortfolioAdmin();
}

// Helper function - replace with your UID
function isPortfolioAdmin() {
  return request.auth != null && request.auth.uid == 'YOUR_FIREBASE_UID_HERE';
}
```

### Storage Rules

Already configured in `firebase/storage.rules`:
```javascript
match /portfolio/{allPaths=**} {
  allow read: if true;
  allow write: if false; // Admin SDK bypasses, or update for app access
}
```

**For Flutter app access**, update to:
```javascript
match /portfolio/{allPaths=**} {
  allow read: if true;
  allow write: if request.auth != null && request.auth.uid == 'YOUR_FIREBASE_UID_HERE';
}
```

---

## Flutter Implementation

### 1. Data Models

```dart
// lib/data/models/portfolio_collection.dart
class PortfolioCollection {
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? cover;
  final int order;
  final bool visible;
  final DateTime createdAt;
  final DateTime updatedAt;

  PortfolioCollection({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.cover,
    this.order = 0,
    this.visible = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PortfolioCollection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PortfolioCollection(
      id: doc.id,
      title: data['title'] ?? '',
      slug: data['slug'] ?? '',
      description: data['description'],
      cover: data['cover'],
      order: data['order'] ?? 0,
      visible: data['visible'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'slug': slug,
    'description': description,
    'cover': cover,
    'order': order,
    'visible': visible,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
```

```dart
// lib/data/models/portfolio_photo.dart
class PortfolioPhoto {
  final String id;
  final String collectionId;
  final String src;
  final String? caption;
  final String? location;
  final String? notes;
  final bool showExif;
  final ExifData? exif;
  final int order;
  final DateTime createdAt;

  PortfolioPhoto({
    required this.id,
    required this.collectionId,
    required this.src,
    this.caption,
    this.location,
    this.notes,
    this.showExif = true,
    this.exif,
    this.order = 0,
    required this.createdAt,
  });

  factory PortfolioPhoto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PortfolioPhoto(
      id: doc.id,
      collectionId: data['collectionId'] ?? '',
      src: data['src'] ?? '',
      caption: data['caption'],
      location: data['location'],
      notes: data['notes'],
      showExif: data['showExif'] ?? true,
      exif: data['exif'] != null ? ExifData.fromMap(data['exif']) : null,
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'collectionId': collectionId,
    'src': src,
    'caption': caption,
    'location': location,
    'notes': notes,
    'showExif': showExif,
    'exif': exif?.toMap(),
    'order': order,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.now(),
  };

  PortfolioPhoto copyWith({
    String? caption,
    String? location,
    String? notes,
    bool? showExif,
    int? order,
  }) => PortfolioPhoto(
    id: id,
    collectionId: collectionId,
    src: src,
    caption: caption ?? this.caption,
    location: location ?? this.location,
    notes: notes ?? this.notes,
    showExif: showExif ?? this.showExif,
    exif: exif,
    order: order ?? this.order,
    createdAt: createdAt,
  );
}

class ExifData {
  final String? camera;
  final String? lens;
  final String? aperture;
  final String? shutter;
  final int? iso;
  final String? focalLength;
  final String? date;

  ExifData({
    this.camera,
    this.lens,
    this.aperture,
    this.shutter,
    this.iso,
    this.focalLength,
    this.date,
  });

  factory ExifData.fromMap(Map<String, dynamic> map) => ExifData(
    camera: map['camera'],
    lens: map['lens'],
    aperture: map['aperture'],
    shutter: map['shutter'],
    iso: map['iso'],
    focalLength: map['focalLength'],
    date: map['date'],
  );

  Map<String, dynamic> toMap() => {
    if (camera != null) 'camera': camera,
    if (lens != null) 'lens': lens,
    if (aperture != null) 'aperture': aperture,
    if (shutter != null) 'shutter': shutter,
    if (iso != null) 'iso': iso,
    if (focalLength != null) 'focalLength': focalLength,
    if (date != null) 'date': date,
  };

  String toDisplayString() {
    final parts = <String>[];
    if (aperture != null) parts.add(aperture!);
    if (shutter != null) parts.add(shutter!);
    if (iso != null) parts.add('ISO $iso');
    if (focalLength != null) parts.add(focalLength!);
    return parts.join(' · ');
  }
}
```

### 2. Repository

```dart
// lib/data/repositories/portfolio_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:exif/exif.dart';

class PortfolioRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ============ Collections ============

  Stream<List<PortfolioCollection>> getCollections() {
    return _firestore
        .collection('portfolio_collections')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PortfolioCollection.fromFirestore(doc))
            .toList());
  }

  Future<PortfolioCollection> createCollection(String title) async {
    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final now = DateTime.now();

    final doc = await _firestore.collection('portfolio_collections').add({
      'title': title,
      'slug': slug,
      'order': 0,
      'visible': true,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return PortfolioCollection(
      id: doc.id,
      title: title,
      slug: slug,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateCollection(PortfolioCollection collection) async {
    await _firestore
        .collection('portfolio_collections')
        .doc(collection.id)
        .update(collection.toFirestore());
  }

  Future<void> deleteCollection(String collectionId) async {
    // Delete all photos in collection first
    final photos = await _firestore
        .collection('portfolio_photos')
        .where('collectionId', isEqualTo: collectionId)
        .get();

    for (final doc in photos.docs) {
      await deletePhoto(doc.id);
    }

    // Delete collection document
    await _firestore
        .collection('portfolio_collections')
        .doc(collectionId)
        .delete();
  }

  // ============ Photos ============

  Stream<List<PortfolioPhoto>> getPhotos(String collectionId) {
    return _firestore
        .collection('portfolio_photos')
        .where('collectionId', isEqualTo: collectionId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PortfolioPhoto.fromFirestore(doc))
            .toList());
  }

  Future<PortfolioPhoto> uploadPhoto({
    required String collectionId,
    required String collectionSlug,
    required File imageFile,
  }) async {
    final photoId = DateTime.now().millisecondsSinceEpoch.toString();

    // Extract EXIF before compression
    final exif = await _extractExif(imageFile);

    // Optimize image (2000px, 85% quality)
    final optimized = await _optimizeImage(imageFile, 2000, 85);

    // Upload to Storage
    final storagePath = 'portfolio/photos/$collectionSlug/$photoId.jpg';
    final ref = _storage.ref().child(storagePath);
    await ref.putFile(optimized, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    // Update collection cover if first photo
    await _updateCoverIfNeeded(collectionId, collectionSlug, imageFile);

    // Create Firestore document
    final doc = await _firestore.collection('portfolio_photos').add({
      'collectionId': collectionId,
      'src': url,
      'showExif': true,
      'exif': exif?.toMap(),
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    // Cleanup temp file
    await optimized.delete();

    return PortfolioPhoto(
      id: doc.id,
      collectionId: collectionId,
      src: url,
      showExif: true,
      exif: exif,
      createdAt: DateTime.now(),
    );
  }

  Future<void> updatePhoto(PortfolioPhoto photo) async {
    await _firestore
        .collection('portfolio_photos')
        .doc(photo.id)
        .update(photo.toFirestore());
  }

  Future<void> deletePhoto(String photoId) async {
    final doc = await _firestore.collection('portfolio_photos').doc(photoId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final src = data['src'] as String?;

    // Delete from Storage
    if (src != null) {
      try {
        final ref = _storage.refFromURL(src);
        await ref.delete();
      } catch (e) {
        // File might not exist
      }
    }

    // Delete Firestore document
    await _firestore.collection('portfolio_photos').doc(photoId).delete();
  }

  // ============ Helpers ============

  Future<File> _optimizeImage(File input, int maxWidth, int quality) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/opt_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      input.path,
      targetPath,
      minWidth: maxWidth,
      minHeight: maxWidth,
      quality: quality,
      autoCorrectionAngle: true,  // Auto-rotate based on EXIF
      keepExif: false,
    );

    return File(result!.path);
  }

  Future<ExifData?> _extractExif(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final data = await readExifFromBytes(bytes);

      if (data.isEmpty) return null;

      String? formatShutter(dynamic value) {
        if (value == null) return null;
        final ratio = value as Ratio;
        final t = ratio.numerator / ratio.denominator;
        return t >= 1 ? '${t}s' : '1/${(1 / t).round()}s';
      }

      return ExifData(
        camera: '${data['Image Make']} ${data['Image Model'] ?? ''}'.trim(),
        lens: data['EXIF LensModel']?.toString(),
        aperture: data['EXIF FNumber'] != null
            ? 'f/${(data['EXIF FNumber'] as Ratio).numerator / (data['EXIF FNumber'] as Ratio).denominator}'
            : null,
        shutter: formatShutter(data['EXIF ExposureTime']),
        iso: data['EXIF ISOSpeedRatings']?.values.first,
        focalLength: data['EXIF FocalLength'] != null
            ? '${(data['EXIF FocalLength'] as Ratio).numerator / (data['EXIF FocalLength'] as Ratio).denominator}mm'
            : null,
        date: data['EXIF DateTimeOriginal']?.toString().split(' ').first.replaceAll(':', '-'),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateCoverIfNeeded(
    String collectionId,
    String collectionSlug,
    File imageFile,
  ) async {
    final collection = await _firestore
        .collection('portfolio_collections')
        .doc(collectionId)
        .get();

    if (collection.data()?['cover'] != null) return;

    // Create cover thumbnail (600px)
    final thumb = await _optimizeImage(imageFile, 600, 80);
    final coverPath = 'portfolio/photos/$collectionSlug/_cover.jpg';
    final ref = _storage.ref().child(coverPath);
    await ref.putFile(thumb, SettableMetadata(contentType: 'image/jpeg'));
    final coverUrl = await ref.getDownloadURL();

    await _firestore
        .collection('portfolio_collections')
        .doc(collectionId)
        .update({'cover': coverUrl, 'updatedAt': Timestamp.now()});

    await thumb.delete();
  }
}
```

### 3. Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  exif: ^3.3.0  # For EXIF extraction
  # (flutter_image_compress, firebase_storage, cloud_firestore already exist)
```

### 4. UI Screens

Create these screens in `lib/ui/screens/portfolio/`:

- `portfolio_collections_screen.dart` - List of collections with add/edit/delete
- `portfolio_collection_detail_screen.dart` - Grid of photos in a collection
- `portfolio_photo_edit_screen.dart` - Edit caption, location, notes, toggle showExif

**Key UI Features**:
- Drag-to-reorder for both collections and photos
- Swipe-to-delete or long-press menu
- Image picker for adding photos (camera + gallery)
- Form fields for caption, location, notes
- Toggle switch for showExif
- Full EXIF display (read-only)

### 5. Navigation

Add to the app's main navigation (maybe in settings or as a separate admin section):

```dart
// Only show if user is the portfolio admin
if (currentUser?.uid == 'YOUR_FIREBASE_UID_HERE')
  ListTile(
    leading: Icon(Icons.photo_library),
    title: Text('Portfolio'),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PortfolioCollectionsScreen()),
    ),
  ),
```

---

## Portfolio Website Changes

**Already implemented!** The website now loads from Firestore with fallback to static data.js.

### Files Added/Modified

1. **`index.html`** - Added Firebase SDK:
```html
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-firestore-compat.js"></script>
```

2. **`assets/js/firebase-config.js`** - Firebase initialization + Firestore loader:
   - Initializes Firebase with project config
   - `loadAllPhotoCollections()` - loads from Firestore, merges with static data.js
   - Firestore collections take priority over static data

3. **`assets/js/router.js`** - Updated `loadPhotoCollections()`:
   - Now async, calls `loadAllPhotoCollections()`
   - Shows "Loading..." state while fetching
   - Supports both string IDs (Firestore) and numeric IDs (static)

### How It Works

```
Website loads
    ↓
loadAllPhotoCollections() called
    ↓
┌─────────────────────────────────────┐
│ Try Firestore:                      │
│   portfolio_collections (visible)   │
│   portfolio_photos (per collection) │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Merge with static data.js           │
│ (Firestore takes priority)          │
└─────────────────────────────────────┘
    ↓
Display collections
```

### Two Upload Methods

| Method | Source | Use Case |
|--------|--------|----------|
| Terminal (`npm run upload-photos`) | → data.js (static) | Quick uploads from computer |
| Flutter app | → Firestore (dynamic) | Mobile management, editing |

Both sources are merged on the website. Firestore entries override static entries with the same title

---

## Migration Steps

1. **Deploy Firestore rules** with portfolio collections
2. **Deploy Storage rules** with your UID
3. **Implement Flutter screens** (can be done incrementally)
4. **Migrate existing photos**:
   - Run upload script one more time
   - Or create a migration script to copy data.js → Firestore
5. **Update website** to load from Firestore
6. **Test the full flow**: App → Firestore → Website

---

## Summary

| Component | Technology | Access |
|-----------|------------|--------|
| Admin UI | Flutter app | Auth (your UID only) |
| Data store | Firestore | Public read, admin write |
| Image storage | Firebase Storage | Public read, admin write |
| Website | Vanilla JS | Public (reads Firestore) |

This gives you full control over your portfolio photos from your phone, with instant updates to the website.
