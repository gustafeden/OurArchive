import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../data/models/music_metadata.dart';
import '../../../data/models/item.dart';
import '../../../data/models/discogs_search_result.dart';
import '../../../services/music_lookup_service.dart';
import '../../../providers/providers.dart';
import '../common/network_image_with_fallback.dart';

/// Result from music selection dialog
class MusicSelectionResult {
  final MusicMetadata music;
  final String action; // 'add' or 'preview'

  MusicSelectionResult({
    required this.music,
    required this.action,
  });
}

/// Shows an enhanced selection dialog when multiple music releases match a barcode.
///
/// Features:
/// - Visual indicators for owned releases (badge, color, location)
/// - Pagination support with "Load More" button
/// - Owned releases sorted to top of list
///
/// Returns the MusicSelectionResult or null if cancelled.
Future<MusicSelectionResult?> showMusicSelectionDialog({
  required BuildContext context,
  required String barcode,
  required List<MusicMetadata> initialResults,
  required PaginationInfo initialPagination,
  required List<Item> ownedItems,
  required String householdId,
}) async {
  return showDialog<MusicSelectionResult>(
    context: context,
    builder: (dialogContext) => _MusicSelectionDialog(
      barcode: barcode,
      initialResults: initialResults,
      initialPagination: initialPagination,
      ownedItems: ownedItems,
      householdId: householdId,
    ),
  );
}

class _MusicSelectionDialog extends ConsumerStatefulWidget {
  final String barcode;
  final List<MusicMetadata> initialResults;
  final PaginationInfo initialPagination;
  final List<Item> ownedItems;
  final String householdId;

  const _MusicSelectionDialog({
    required this.barcode,
    required this.initialResults,
    required this.initialPagination,
    required this.ownedItems,
    required this.householdId,
  });

  @override
  ConsumerState<_MusicSelectionDialog> createState() => _MusicSelectionDialogState();
}

class _MusicSelectionDialogState extends ConsumerState<_MusicSelectionDialog> {
  late List<MusicMetadata> _results;
  late PaginationInfo _pagination;
  bool _isLoadingMore = false;
  Map<String, String>? _containerNames; // Cache container names

  @override
  void initState() {
    super.initState();
    _results = _sortResults(widget.initialResults);
    _pagination = widget.initialPagination;
    _loadContainerNames();
  }

  /// Sort results to show owned items first
  List<MusicMetadata> _sortResults(List<MusicMetadata> results) {
    final owned = <MusicMetadata>[];
    final notOwned = <MusicMetadata>[];

    for (final music in results) {
      if (_isOwned(music)) {
        owned.add(music);
      } else {
        notOwned.add(music);
      }
    }

    return [...owned, ...notOwned];
  }

  /// Check if a music release is owned
  bool _isOwned(MusicMetadata music) {
    return widget.ownedItems.any((item) => item.discogsId != null && item.discogsId == music.discogsId);
  }

  /// Get owned item for a music release
  Item? _getOwnedItem(MusicMetadata music) {
    try {
      return widget.ownedItems.firstWhere((item) => item.discogsId != null && item.discogsId == music.discogsId);
    } catch (e) {
      return null;
    }
  }

  /// Load container names for owned items
  Future<void> _loadContainerNames() async {
    final names = <String, String>{};
    final containerService = ref.read(containerServiceProvider);

    try {
      final containers = await containerService.getAllContainers(widget.householdId).first;

      for (final item in widget.ownedItems) {
        if (item.containerId != null) {
          try {
            final container = containers.firstWhere(
              (c) => c.id == item.containerId,
            );
            names[item.id] = container.name;
          } catch (e) {
            // Container not found
          }
        }
      }

      if (mounted) {
        setState(() {
          _containerNames = names;
        });
      }
    } catch (e) {
      // Error loading containers
    }
  }

  /// Load more results from next page
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_pagination.hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _pagination.currentPage + 1;
      final result = await MusicLookupService.lookupByBarcodeWithPagination(
        widget.barcode,
        page: nextPage,
        perPage: _pagination.perPage,
      );

      if (mounted) {
        setState(() {
          _results.addAll(result.results);
          _results = _sortResults(_results); // Re-sort with new results
          _pagination = result.pagination;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingText =
        _pagination.hasMore ? 'showing ${_results.length} of ${_pagination.totalItems}' : '${_results.length} matches';

    return AlertDialog(
      title: Text('Select Release ($showingText)'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final music = _results[index];
                  final ownedItem = _getOwnedItem(music);
                  final isOwned = ownedItem != null;
                  final containerName =
                      ownedItem != null && _containerNames != null ? _containerNames![ownedItem.id] : null;

                  return _MusicSelectionItem(
                    music: music,
                    isOwned: isOwned,
                    ownedQuantity: ownedItem?.quantity ?? 0,
                    containerName: containerName,
                    onTap: () => Navigator.pop(
                      context,
                      MusicSelectionResult(music: music, action: 'add'),
                    ),
                    onPreview: () => Navigator.pop(
                      context,
                      MusicSelectionResult(music: music, action: 'preview'),
                    ),
                  );
                },
              ),
            ),
            // Load More button
            if (_pagination.hasMore) ...[
              const SizedBox(height: 16),
              if (_isLoadingMore)
                const CircularProgressIndicator()
              else
                OutlinedButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Ionicons.chevron_down_outline),
                  label: Text('Load More Results (${_pagination.totalItems - _results.length} remaining)'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MusicSelectionItem extends StatelessWidget {
  final MusicMetadata music;
  final bool isOwned;
  final int ownedQuantity;
  final String? containerName;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  const _MusicSelectionItem({
    required this.music,
    required this.isOwned,
    required this.ownedQuantity,
    required this.containerName,
    required this.onTap,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isOwned ? Colors.green.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Owned checkmark
            if (isOwned)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                child: Icon(
                  Ionicons.checkmark_circle,
                  color: Colors.green[700],
                  size: 24,
                ),
              ),
            // Cover image thumbnail
            SizedBox(
              width: 80,
              child: NetworkImageWithFallback(
                imageUrl: music.coverUrl,
                height: 80,
                fallbackIcon: Ionicons.disc_outline,
                fallbackIconSize: 40,
                centered: false,
              ),
            ),
            const SizedBox(width: 12),
            // Music details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Owned badge
                  if (isOwned) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ownedQuantity > 1 ? 'Owned (qty: $ownedQuantity)' : 'Owned',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Title
                  Text(
                    music.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Artist
                  if (music.artist.isNotEmpty)
                    Text(
                      music.artist,
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
                      if (music.format != null && music.format!.isNotEmpty)
                        _DetailChip(
                          label: music.format!.join(', '),
                          icon: Ionicons.disc_outline,
                        ),
                      if (music.country != null && music.country!.isNotEmpty)
                        _DetailChip(
                          label: music.country!,
                          icon: Ionicons.flag_outline,
                        ),
                      if (music.year != null)
                        _DetailChip(
                          label: music.year.toString(),
                          icon: Ionicons.calendar_outline,
                        ),
                    ],
                  ),
                  // Label and catalog number
                  if (music.label != null && music.label!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      music.catalogNumber != null && music.catalogNumber!.isNotEmpty
                          ? '${music.label!} - ${music.catalogNumber!}'
                          : music.label!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Container location (if owned)
                  if (isOwned && containerName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Ionicons.location_outline,
                          size: 14,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'In: $containerName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Vertical button stack
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Preview button (if callback provided)
                if (onPreview != null) ...[
                  IconButton(
                    icon: const Icon(Ionicons.play_circle_outline),
                    onPressed: onPreview,
                    tooltip: 'Preview tracks',
                    color: Theme.of(context).colorScheme.primary,
                    iconSize: 32,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 4),
                ],
                // Selection arrow button
                IconButton(
                  icon: const Icon(Ionicons.chevron_forward_outline),
                  onPressed: onTap,
                  tooltip: 'Add to collection',
                  color: Theme.of(context).colorScheme.primary,
                  iconSize: 28,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
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
