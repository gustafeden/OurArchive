import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../models/track.dart';
import '../../core/sync/sync_queue.dart';

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
    final itemId = const Uuid().v4();

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

  // Move item to a different container (or null for unorganized)
  Future<void> moveItem({
    required String householdId,
    required String itemId,
    required String? newContainerId,
  }) async {
    try {
      final docRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('items')
          .doc(itemId);

      await docRef.update({
        'containerId': newContainerId,
        'lastModified': Timestamp.fromDate(DateTime.now()),
      });
    } catch (error) {
      // Queue for retry
      _syncQueue.add(SyncTask(
        id: 'move_item_$itemId',
        execute: () async {
          final docRef = _firestore
              .collection('households')
              .doc(householdId)
              .collection('items')
              .doc(itemId);

          await docRef.update({
            'containerId': newContainerId,
            'lastModified': Timestamp.fromDate(DateTime.now()),
          });
        },
      ));
      rethrow;
    }
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
      image.absolute.path,
      targetPath,
      minWidth: 200,
      minHeight: 200,
      quality: 70,
    );

    return File(result!.path);
  }

  // Upload photo to storage and return paths (doesn't update Firestore)
  Future<Map<String, String>> uploadPhotoToStorage({
    required String householdId,
    required String itemId,
    required String userId,
    required File photo,
  }) async {
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

    return {
      'photoPath': imagePath,
      'photoThumbPath': thumbPath,
    };
  }

  // Delete old photos from storage
  Future<void> deleteOldPhotos({
    String? oldPhotoPath,
    String? oldPhotoThumbPath,
  }) async {
    if (oldPhotoPath != null) {
      try {
        await _storage.ref().child(oldPhotoPath).delete();
      } catch (e) {
        // Ignore errors when deleting old photos (they might not exist)
      }
    }
    if (oldPhotoThumbPath != null) {
      try {
        await _storage.ref().child(oldPhotoThumbPath).delete();
      } catch (e) {
        // Ignore errors when deleting old thumbnails
      }
    }
  }

  // Get items stream with offline support
  Stream<List<Item>> getItems(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Item.fromFirestore(doc))
            .where((item) => item.deletedAt == null) // Filter deleted items in memory
            .toList());
  }

  // Find item by ISBN in a household
  // Note: Searches in memory rather than using Firestore query to avoid needing an index
  Future<Item?> findItemByIsbn(String householdId, String isbn) async {
    // Clean ISBN for consistent matching
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '').toLowerCase();

    // Get all items for the household
    final snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .get();

    // Search through items in memory
    for (final doc in snapshot.docs) {
      final item = Item.fromFirestore(doc);

      // Skip deleted items
      if (item.deletedAt != null) continue;

      // Check if ISBN matches (case-insensitive, cleaned)
      if (item.isbn != null) {
        final itemIsbn = item.isbn!.replaceAll(RegExp(r'[^0-9X]'), '').toLowerCase();
        if (itemIsbn == cleanIsbn) {
          return item;
        }
      }

      // Also check barcode field as fallback
      if (item.barcode != null) {
        final itemBarcode = item.barcode!.replaceAll(RegExp(r'[^0-9X]'), '').toLowerCase();
        if (itemBarcode == cleanIsbn) {
          return item;
        }
      }
    }

    return null;
  }

  // Find item by barcode in a household (alias for findItemByIsbn since both use barcode field)
  Future<Item?> findItemByBarcode(String householdId, String barcode) async {
    return findItemByIsbn(householdId, barcode);
  }

  // Find item by discogsId in a household
  Future<Item?> findItemByDiscogsId(String householdId, String discogsId) async {
    if (discogsId.isEmpty) return null;

    // Get all items for the household
    final snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .get();

    // Search through items in memory
    for (final doc in snapshot.docs) {
      final item = Item.fromFirestore(doc);

      // Skip deleted items
      if (item.deletedAt != null) continue;

      // Check if discogsId matches
      if (item.discogsId != null && item.discogsId == discogsId) {
        return item;
      }
    }

    return null;
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

  /// Update tracks for an item (lightweight update without version check)
  Future<void> updateItemTracks({
    required String householdId,
    required String itemId,
    required List<Track> tracks,
  }) async {
    try {
      final docRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('items')
          .doc(itemId);

      await docRef.update({
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'lastModified': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log error but don't throw - track caching is not critical
      print('Error updating tracks for item $itemId: $e');
    }
  }

  // Get download URL for photo
  Future<String?> getPhotoUrl(String? photoPath) async {
    if (photoPath == null) return null;
    try {
      return await _storage.ref().child(photoPath).getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}
