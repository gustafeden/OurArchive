import 'package:ionicons/ionicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/household.dart';
import '../../../data/models/item.dart';
import '../../../providers/providers.dart';
import '../../../utils/icon_helper.dart';
import '../../screens/item_detail_screen.dart';

/// A reusable card widget for displaying items in a list.
///
/// This widget handles:
/// - Item thumbnail with async loading
/// - Type-aware subtitles (book authors, vinyl artists, game platforms)
/// - Navigation to item detail screen
/// - Optional edit mode with move/delete buttons
/// - Optional sync status indicator
class ItemCardWidget extends ConsumerWidget {
  /// The item to display
  final Item item;

  /// The household this item belongs to (needed for navigation)
  final Household household;

  /// Whether to show edit mode buttons (move/delete)
  final bool showEditActions;

  /// Callback when move button is pressed (only used if showEditActions is true)
  final VoidCallback? onMoveItem;

  /// Callback when delete button is pressed (only used if showEditActions is true)
  final VoidCallback? onDeleteItem;

  /// Whether to show sync status icon
  final bool showSyncStatus;

  /// Whether to show location emoji in subtitle for generic items
  final bool showLocationInSubtitle;

  const ItemCardWidget({
    super.key,
    required this.item,
    required this.household,
    this.showEditActions = false,
    this.onMoveItem,
    this.onDeleteItem,
    this.showSyncStatus = false,
    this.showLocationInSubtitle = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildThumbnail(ref),
        title: Text(item.title),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(
                item: item,
                household: household,
              ),
            ),
          );
        },
        onLongPress: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(
                item: item,
                household: household,
                openInEditMode: true,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(WidgetRef ref) {
    if (item.photoThumbPath == null) {
      return CircleAvatar(
        child: Icon(IconHelper.getItemIcon(item.type)),
      );
    }

    final itemRepo = ref.read(itemRepositoryProvider);

    return FutureBuilder<String?>(
      future: itemRepo.getPhotoUrl(item.photoThumbPath!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(snapshot.data!),
          );
        }
        return CircleAvatar(
          child: Icon(IconHelper.getItemIcon(item.type)),
        );
      },
    );
  }

  Widget _buildSubtitle() {
    // Type-aware subtitle display
    switch (item.type) {
      case 'book':
        if (item.authors != null && item.authors!.isNotEmpty) {
          return Text(item.authors!.join(', '));
        }
        return const Text('Unknown Author');

      case 'vinyl':
        if (item.artist != null && item.artist!.isNotEmpty) {
          return Text(item.artist!);
        }
        return const Text('Unknown Artist');

      case 'game':
        if (item.platform != null) {
          return Text(item.platform!);
        }
        return const Text('Game');

      default:
        // Generic items - two different display modes
        if (showLocationInSubtitle) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.type),
              if (item.location.isNotEmpty) Text('📍 ${item.location}'),
              if (item.quantity > 1) Text('Qty: ${item.quantity}'),
            ],
          );
        } else {
          return Text('${item.type} • Qty: ${item.quantity}');
        }
    }
  }

  Widget? _buildTrailing() {
    if (showEditActions) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Ionicons.folder_open_outline),
            onPressed: onMoveItem,
            tooltip: 'Move to another container',
          ),
          IconButton(
            icon: const Icon(Ionicons.trash_outline, color: Colors.red),
            onPressed: onDeleteItem,
            tooltip: 'Delete item',
          ),
          const Icon(Ionicons.chevron_forward_outline),
        ],
      );
    } else if (showSyncStatus && item.syncStatus != SyncStatus.synced) {
      return const Icon(Ionicons.sync_outline, size: 16);
    } else {
      return null;
    }
  }
}
