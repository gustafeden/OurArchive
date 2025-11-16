import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/household.dart';
import '../models/container.dart' as model;
import '../repositories/container_repository.dart';
import 'container_service.dart';

/// Service for preloading container thumbnails in the background
/// to improve perceived performance when viewing households
class ThumbnailPreloadService {
  static const int _maxConcurrentDownloads = 5;

  /// Preload thumbnails for all containers in all user households
  ///
  /// This method:
  /// - Fetches all containers for each household
  /// - Gets download URLs for container thumbnails
  /// - Precaches images using Flutter's image cache
  /// - Throttles concurrent downloads to avoid network saturation
  /// - Fails silently to avoid disrupting user experience
  Future<void> preloadAllHouseholdThumbnails({
    required List<Household> households,
    required BuildContext context,
    required ContainerService containerService,
    required ContainerRepository containerRepository,
  }) async {
    if (!context.mounted || households.isEmpty) return;

    try {
      // Process first household with priority (most likely to be viewed)
      if (households.isNotEmpty) {
        await _preloadHouseholdThumbnails(
          household: households.first,
          context: context,
          containerService: containerService,
          containerRepository: containerRepository,
        );
      }

      // Process remaining households
      for (var i = 1; i < households.length; i++) {
        if (!context.mounted) return; // Stop if screen is no longer visible

        await _preloadHouseholdThumbnails(
          household: households[i],
          context: context,
          containerService: containerService,
          containerRepository: containerRepository,
        );
      }
    } catch (e) {
      // Silent failure - preloading is an optimization, not critical
      debugPrint('Thumbnail preload error: $e');
    }
  }

  /// Preload thumbnails for a single household
  Future<void> _preloadHouseholdThumbnails({
    required Household household,
    required BuildContext context,
    required ContainerService containerService,
    required ContainerRepository containerRepository,
  }) async {
    if (!context.mounted) return;

    try {
      // Get all containers for this household
      final containers = await containerService
          .getAllContainers(household.id)
          .first
          .timeout(const Duration(seconds: 10));

      if (!context.mounted) return;

      // Filter containers that have thumbnails
      final containersWithThumbnails = containers
          .where((c) => c.photoThumbPath != null)
          .toList();

      if (containersWithThumbnails.isEmpty) return;

      // Preload in batches to throttle concurrent downloads
      await _preloadContainerThumbnailsBatched(
        containers: containersWithThumbnails,
        context: context,
        containerRepository: containerRepository,
      );
    } catch (e) {
      debugPrint('Error preloading household ${household.id}: $e');
    }
  }

  /// Preload container thumbnails in batches to limit concurrent downloads
  Future<void> _preloadContainerThumbnailsBatched({
    required List<model.Container> containers,
    required BuildContext context,
    required ContainerRepository containerRepository,
  }) async {
    // Process containers in batches
    for (var i = 0; i < containers.length; i += _maxConcurrentDownloads) {
      if (!context.mounted) return;

      final batch = containers.skip(i).take(_maxConcurrentDownloads).toList();

      // Process batch concurrently
      await Future.wait(
        batch.map((container) => _preloadSingleThumbnail(
          container: container,
          context: context,
          containerRepository: containerRepository,
        )),
        eagerError: false, // Continue even if some fail
      );
    }
  }

  /// Preload a single container thumbnail
  Future<void> _preloadSingleThumbnail({
    required model.Container container,
    required BuildContext context,
    required ContainerRepository containerRepository,
  }) async {
    if (!context.mounted || container.photoThumbPath == null) return;

    try {
      // Get download URL from Firebase Storage
      final url = await containerRepository
          .getPhotoUrl(container.photoThumbPath!)
          .timeout(const Duration(seconds: 5));

      if (url == null || !context.mounted) return;

      // Precache the image
      await precacheImage(
        CachedNetworkImageProvider(url),
        context,
        onError: (exception, stackTrace) {
          debugPrint('Error precaching image for ${container.name}: $exception');
        },
      );
    } catch (e) {
      // Silent failure - individual thumbnail failures shouldn't break preloading
      debugPrint('Error loading thumbnail for ${container.name}: $e');
    }
  }
}
