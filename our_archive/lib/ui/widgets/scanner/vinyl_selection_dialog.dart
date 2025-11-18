import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../../../data/models/vinyl_metadata.dart';
import '../common/network_image_with_fallback.dart';

/// Shows a selection dialog when multiple vinyl releases match a barcode.
///
/// Returns the selected VinylMetadata or null if cancelled.
///
/// Usage:
/// ```dart
/// final selected = await showVinylSelectionDialog(
///   context: context,
///   results: vinylList,
/// );
/// ```
Future<VinylMetadata?> showVinylSelectionDialog({
  required BuildContext context,
  required List<VinylMetadata> results,
}) async {
  return showDialog<VinylMetadata>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(results.length == 1
          ? 'Select Release'
          : 'Select Release (${results.length} matches)'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final vinyl = results[index];
            return _VinylSelectionItem(
              vinyl: vinyl,
              onTap: () => Navigator.pop(dialogContext, vinyl),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, null),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class _VinylSelectionItem extends StatelessWidget {
  final VinylMetadata vinyl;
  final VoidCallback onTap;

  const _VinylSelectionItem({
    required this.vinyl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image thumbnail
            SizedBox(
              width: 80,
              child: NetworkImageWithFallback(
                imageUrl: vinyl.coverUrl,
                height: 80,
                fallbackIcon: Ionicons.disc_outline,
                fallbackIconSize: 40,
                centered: false,
              ),
            ),
            const SizedBox(width: 12),
            // Vinyl details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    vinyl.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Artist
                  if (vinyl.artist.isNotEmpty)
                    Text(
                      vinyl.artist,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  // Format, Country, Year
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (vinyl.format != null && vinyl.format!.isNotEmpty)
                        _DetailChip(
                          label: vinyl.format!.join(', '),
                          icon: Ionicons.disc_outline,
                        ),
                      if (vinyl.country != null && vinyl.country!.isNotEmpty)
                        _DetailChip(
                          label: vinyl.country!,
                          icon: Ionicons.flag_outline,
                        ),
                      if (vinyl.year != null)
                        _DetailChip(
                          label: vinyl.year.toString(),
                          icon: Ionicons.calendar_outline,
                        ),
                    ],
                  ),
                  // Label and catalog number
                  if (vinyl.label != null && vinyl.label!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      vinyl.catalogNumber != null && vinyl.catalogNumber!.isNotEmpty
                          ? '${vinyl.label!} - ${vinyl.catalogNumber!}'
                          : vinyl.label!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Selection indicator
            Icon(
              Ionicons.chevron_forward_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _DetailChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
