import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:exif/exif.dart' hide ExifData;

import '../models/portfolio_collection.dart';
import '../models/portfolio_photo.dart';

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

    // Get the highest order value
    final existing = await _firestore
        .collection('portfolio_collections')
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder =
        existing.docs.isEmpty ? 0 : (existing.docs.first.data()['order'] ?? 0) + 1;

    final doc = await _firestore.collection('portfolio_collections').add({
      'title': title,
      'slug': slug,
      'order': nextOrder,
      'visible': true,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return PortfolioCollection(
      id: doc.id,
      title: title,
      slug: slug,
      order: nextOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateCollection(PortfolioCollection collection) async {
    await _firestore
        .collection('portfolio_collections')
        .doc(collection.id)
        .update({
      ...collection.toFirestore(),
      'updatedAt': Timestamp.now(),
    });
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

    // Get collection slug to delete storage folder
    final collectionDoc = await _firestore
        .collection('portfolio_collections')
        .doc(collectionId)
        .get();
    final slug = collectionDoc.data()?['slug'] as String?;

    // Delete cover image if exists
    if (slug != null) {
      try {
        await _storage.ref().child('portfolio/photos/$slug/_cover.jpg').delete();
      } catch (e) {
        // Cover might not exist
      }
    }

    // Delete collection document
    await _firestore
        .collection('portfolio_collections')
        .doc(collectionId)
        .delete();
  }

  Future<void> reorderCollections(List<PortfolioCollection> collections) async {
    final batch = _firestore.batch();
    for (var i = 0; i < collections.length; i++) {
      batch.update(
        _firestore.collection('portfolio_collections').doc(collections[i].id),
        {'order': i, 'updatedAt': Timestamp.now()},
      );
    }
    await batch.commit();
  }

  // ============ Photos ============

  Stream<List<PortfolioPhoto>> getPhotos(String collectionId) {
    return _firestore
        .collection('portfolio_photos')
        .where('collectionId', isEqualTo: collectionId)
        .orderBy('order')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => PortfolioPhoto.fromFirestore(doc)).toList());
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

    // Get highest order
    final existing = await _firestore
        .collection('portfolio_photos')
        .where('collectionId', isEqualTo: collectionId)
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder =
        existing.docs.isEmpty ? 0 : (existing.docs.first.data()['order'] ?? 0) + 1;

    // Create Firestore document
    final doc = await _firestore.collection('portfolio_photos').add({
      'collectionId': collectionId,
      'src': url,
      'showExif': true,
      'exif': exif?.toMap(),
      'order': nextOrder,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    // Cleanup temp file
    try {
      await optimized.delete();
    } catch (e) {
      // Ignore cleanup errors
    }

    return PortfolioPhoto(
      id: doc.id,
      collectionId: collectionId,
      src: url,
      showExif: true,
      exif: exif,
      order: nextOrder,
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
    final doc =
        await _firestore.collection('portfolio_photos').doc(photoId).get();
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

  Future<void> reorderPhotos(List<PortfolioPhoto> photos) async {
    final batch = _firestore.batch();
    for (var i = 0; i < photos.length; i++) {
      batch.update(
        _firestore.collection('portfolio_photos').doc(photos[i].id),
        {'order': i, 'updatedAt': Timestamp.now()},
      );
    }
    await batch.commit();
  }

  Future<void> setCollectionCover(
      String collectionId, String collectionSlug, String photoSrc) async {
    // Download the photo and create a thumbnail
    final ref = _storage.refFromURL(photoSrc);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.writeToFile(tempFile);

    // Create cover thumbnail (600px)
    final thumb = await _optimizeImage(tempFile, 600, 80);
    final coverPath = 'portfolio/photos/$collectionSlug/_cover.jpg';
    final coverRef = _storage.ref().child(coverPath);
    await coverRef.putFile(thumb, SettableMetadata(contentType: 'image/jpeg'));
    final coverUrl = await coverRef.getDownloadURL();

    await _firestore
        .collection('portfolio_collections')
        .doc(collectionId)
        .update({'cover': coverUrl, 'updatedAt': Timestamp.now()});

    // Cleanup
    try {
      await tempFile.delete();
      await thumb.delete();
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  // ============ Helpers ============

  Future<File> _optimizeImage(File input, int maxWidth, int quality) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/opt_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      input.path,
      targetPath,
      minWidth: maxWidth,
      minHeight: maxWidth,
      quality: quality,
      autoCorrectionAngle: true,
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
        try {
          final ratio = value as Ratio;
          final t = ratio.numerator / ratio.denominator;
          return t >= 1 ? '${t}s' : '1/${(1 / t).round()}s';
        } catch (e) {
          return value.toString();
        }
      }

      String? formatAperture(dynamic value) {
        if (value == null) return null;
        try {
          final ratio = value as Ratio;
          final f = ratio.numerator / ratio.denominator;
          return 'f/${f.toStringAsFixed(1)}';
        } catch (e) {
          return 'f/$value';
        }
      }

      String? formatFocalLength(dynamic value) {
        if (value == null) return null;
        try {
          final ratio = value as Ratio;
          final fl = ratio.numerator / ratio.denominator;
          return '${fl.round()}mm';
        } catch (e) {
          return '${value}mm';
        }
      }

      final make = data['Image Make']?.printable ?? '';
      final model = data['Image Model']?.printable ?? '';
      final camera = '$make $model'.trim();

      int? iso;
      try {
        final isoTag = data['EXIF ISOSpeedRatings'];
        if (isoTag != null) {
          iso = isoTag.values.toList().first as int?;
        }
      } catch (e) {
        // Ignore ISO parsing errors
      }

      return ExifData(
        camera: camera.isNotEmpty ? camera : null,
        lens: data['EXIF LensModel']?.printable,
        aperture: formatAperture(data['EXIF FNumber']?.values.toList().first),
        shutter: formatShutter(data['EXIF ExposureTime']?.values.toList().first),
        iso: iso,
        focalLength:
            formatFocalLength(data['EXIF FocalLength']?.values.toList().first),
        date: data['EXIF DateTimeOriginal']
            ?.printable
            .split(' ')
            .first
            .replaceAll(':', '-'),
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

    try {
      await thumb.delete();
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}
