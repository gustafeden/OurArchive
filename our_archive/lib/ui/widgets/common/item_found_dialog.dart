import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item.dart';
import '../../../data/models/container.dart' as model;
import '../../../data/models/track.dart';
import '../../../providers/providers.dart';
import 'network_image_with_fallback.dart';
import '../scanner/track_preview_section.dart';

/// Shows a dialog when an item is found in the collection during scanning.
///
/// This provides a much better UX than a simple "duplicate" message by:
/// - Clear visual feedback with green checkmark and "You Already Have This!" message
/// - Showing the item's location in a highlighted container box
/// - Displaying cover image, title, creator, and quantity
/// - Offering "Scan Next" or "Add Another Copy" actions
///
/// Usage:
/// ```dart
/// final action = await showItemFoundDialog(
///   context: context,
///   ref: ref,
///   item: existingItem,
///   householdId: householdId,
///   itemTypeName: 'Book',
///   fallbackIcon: Ionicons.book_outline,
/// );
/// ```
Future<String?> showItemFoundDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Item item,
  required String householdId,
  String itemTypeName = 'Item',
  IconData fallbackIcon = Ionicons.cube_outline,
  bool showAddCopyOption = false,
  List<Track>? tracks,
  bool isLoadingTracks = false,
  VoidCallback? onLoadTracks,
}) async {
  // Get container name if item has one
  String locationText = 'Not assigned to a container';
  if (item.containerId != null) {
    try {
      final containerService = ref.read(containerServiceProvider);
      final containers = await containerService.getAllContainers(householdId).first;

      final container = containers.firstWhere(
        (c) => c.id == item.containerId,
        orElse: () => model.Container(
          id: '',
          name: 'Unknown',
          householdId: householdId,
          containerType: 'unknown',
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
          createdBy: '',
        ),
      );

      if (container.id.isNotEmpty) {
        locationText = 'In: ${container.name}';
      }
    } catch (e) {
      locationText = 'Location unavailable';
    }
  }

  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Ionicons.checkmark_circle_outline, color: Colors.green, size: 28),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('You Already Have This!'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            NetworkImageWithFallback(
              imageUrl: item.coverUrl,
              height: 200,
              fallbackIcon: fallbackIcon,
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              item.title,
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            // Creator (author/artist)
            if (item.authors != null && item.authors!.isNotEmpty)
              Text(
                'By ${item.authors!.join(", ")}',
                style: Theme.of(dialogContext).textTheme.bodyLarge,
              )
            else if (item.artist != null && item.artist!.isNotEmpty)
              Text(
                'By ${item.artist}',
                style: Theme.of(dialogContext).textTheme.bodyLarge,
              ),
            const SizedBox(height: 16),

            // Location container (highlighted)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Ionicons.location_outline,
                    color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationText,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Quantity
            if (item.quantity > 1) ...[
              const SizedBox(height: 8),
              Text(
                'Quantity: ${item.quantity}',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
            ],

            // Track preview section
            TrackPreviewSection(
              tracks: tracks,
              isLoading: isLoadingTracks,
              onLoadTracks: onLoadTracks,
              item: item, // Pass item for iTunes preview lookup
            ),
          ],
        ),
      ),
      actions: [
        if (showAddCopyOption)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'addCopy'),
            child: const Text('Add Another Copy'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'scanNext'),
          child: const Text('Scan Next'),
        ),
        if (!showAddCopyOption)
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'close'),
            child: const Text('Close'),
          ),
      ],
    ),
  );
}
