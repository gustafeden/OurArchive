import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../common/network_image_with_fallback.dart';
import 'track_preview_section.dart';
import '../../../data/models/track.dart';
import '../../../data/models/item.dart';

/// A metadata field to display in the item not found dialog
class ItemNotFoundField {
  final String label;
  final String value;
  final int? maxLines;
  final TextOverflow? overflow;

  const ItemNotFoundField({
    required this.label,
    required this.value,
    this.maxLines,
    this.overflow,
  });
}

/// Shows a dialog indicating an item is not in the user's collection.
///
/// This template is used in scan-to-check flows to inform users that a scanned
/// item was not found in their collection, with an option to add it.
///
/// Features an orange warning icon to differentiate from "already have" dialogs.
///
/// Returns one of: 'add', 'scanNext', 'close', or null (cancelled)
///
/// Usage:
/// ```dart
/// final action = await showItemNotFoundDialog(
///   context: context,
///   imageUrl: book.thumbnailUrl,
///   fallbackIcon: Ionicons.book_outline,
///   itemTitle: book.title ?? 'Unknown Title',
///   creator: book.authors.isNotEmpty ? book.authorsDisplay : null,
///   metadataFields: [
///     if (book.publisher != null) ItemNotFoundField(label: 'Publisher', value: book.publisher!),
///     if (book.publishedDate != null) ItemNotFoundField(label: 'Published', value: book.publishedDate!),
///     if (book.description != null)
///       ItemNotFoundField(
///         label: '',
///         value: book.description!,
///         maxLines: 3,
///         overflow: TextOverflow.ellipsis,
///       ),
///   ],
///   addActionLabel: 'Add to Collection',
/// );
/// ```
Future<String?> showItemNotFoundDialog({
  required BuildContext context,
  required String? imageUrl,
  required IconData fallbackIcon,
  required String itemTitle,
  String? creator,
  List<ItemNotFoundField> metadataFields = const [],
  required String addActionLabel,
  List<Track>? tracks,
  bool isLoadingTracks = false,
  VoidCallback? onLoadTracks,
  Item? item, // For iTunes preview lookup
}) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(
            Ionicons.information_circle_outline,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Not in Your Collection'),
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
              imageUrl: imageUrl,
              height: 200,
              fallbackIcon: fallbackIcon,
            ),
            const SizedBox(height: 16),

            // Item title
            Text(
              itemTitle,
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),

            // Creator (author/artist)
            if (creator != null && creator.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'By $creator',
                style: Theme.of(dialogContext).textTheme.bodyLarge,
              ),
            ],

            // Additional metadata fields
            if (metadataFields.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...metadataFields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    field.label.isEmpty ? field.value : '${field.label}: ${field.value}',
                    maxLines: field.maxLines,
                    overflow: field.overflow,
                    style: field.label.isEmpty
                        ? Theme.of(dialogContext).textTheme.bodySmall
                        : Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                ),
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
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'close'),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'scanNext'),
          child: const Text('Scan Next'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'add'),
          icon: const Icon(Ionicons.add_outline),
          label: Text(addActionLabel),
        ),
      ],
    ),
  );
}
