import 'package:flutter/material.dart';
import '../common/network_image_with_fallback.dart';

/// A metadata field to display in the item preview dialog
class ItemPreviewField {
  final String label;
  final String value;

  const ItemPreviewField({
    required this.label,
    required this.value,
  });
}

/// Shows a preview dialog for an item found via scanning (book, vinyl, etc.).
///
/// This template replaces duplicated preview dialogs across scanner screens
/// with a flexible, reusable implementation.
///
/// Returns one of: 'add', 'scanNext', or null (cancelled)
///
/// Usage:
/// ```dart
/// final action = await showItemPreviewDialog(
///   context: context,
///   title: 'Book Found',
///   imageUrl: book.thumbnailUrl,
///   fallbackIcon: Ionicons.book_outline,
///   itemTitle: book.title ?? 'Unknown Title',
///   creator: book.authors.isNotEmpty ? book.authors.join(', ') : null,
///   metadataFields: [
///     if (book.isbn.isNotEmpty) ItemPreviewField(label: 'ISBN', value: book.isbn),
///     if (book.publisher != null) ItemPreviewField(label: 'Publisher', value: book.publisher!),
///   ],
///   primaryActionLabel: 'Add Book',
///   showCancelButton: true,
/// );
/// ```
Future<String?> showItemPreviewDialog({
  required BuildContext context,
  required String title,
  required String? imageUrl,
  required IconData fallbackIcon,
  required String itemTitle,
  String? creator,
  List<ItemPreviewField> metadataFields = const [],
  required String primaryActionLabel,
  bool showCancelButton = true,
}) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
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
              style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            // Creator (author/artist)
            if (creator != null && creator.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'by $creator',
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
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (showCancelButton)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'scanNext'),
          child: const Text('Scan Next'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, 'add'),
          child: Text(primaryActionLabel),
        ),
      ],
    ),
  );
}
