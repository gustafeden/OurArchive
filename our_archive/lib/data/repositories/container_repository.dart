import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ContainerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload photo for a container and return the storage paths
  Future<Map<String, String>> uploadPhoto({
    required String householdId,
    required String containerId,
    required String userId,
    required File photo,
  }) async {
    // Generate thumbnail
    final thumbFile = await _generateThumbnail(photo);

    // Upload full image
    final imagePath = 'households/$householdId/containers/$containerId/image.jpg';
    final imageRef = _storage.ref().child(imagePath);
    final imageMetadata = SettableMetadata(
      customMetadata: {'owner': userId},
      contentType: 'image/jpeg',
    );
    await imageRef.putFile(photo, imageMetadata);

    // Upload thumbnail
    final thumbPath = 'households/$householdId/containers/$containerId/thumb.jpg';
    final thumbRef = _storage.ref().child(thumbPath);
    await thumbRef.putFile(thumbFile, imageMetadata);

    // Clean up temp thumbnail file
    await thumbFile.delete();

    return {
      'photoPath': imagePath,
      'photoThumbPath': thumbPath,
    };
  }

  /// Generate a thumbnail from the original photo
  Future<File> _generateThumbnail(File photo) async {
    final tempDir = await getTemporaryDirectory();
    final thumbPath = '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      photo.absolute.path,
      thumbPath,
      quality: 75,
      minWidth: 400,
      minHeight: 400,
    );

    if (result == null) {
      throw Exception('Failed to generate thumbnail');
    }

    return File(result.path);
  }

  /// Get download URL for a photo from Firebase Storage
  Future<String?> getPhotoUrl(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Delete photos for a container
  Future<void> deletePhotos({
    required String householdId,
    required String containerId,
  }) async {
    try {
      // Delete full image
      final imagePath = 'households/$householdId/containers/$containerId/image.jpg';
      await _storage.ref().child(imagePath).delete();

      // Delete thumbnail
      final thumbPath = 'households/$householdId/containers/$containerId/thumb.jpg';
      await _storage.ref().child(thumbPath).delete();
    } catch (e) {
      // Ignore errors if files don't exist
    }
  }
}
