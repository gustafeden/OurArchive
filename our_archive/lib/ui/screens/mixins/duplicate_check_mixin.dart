import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:our_archive/providers/music_providers.dart';
import '../../../data/models/item.dart';
import '../../../data/models/item_type.dart';
import '../../../data/models/track.dart';
import '../../../providers/providers.dart';
import '../../widgets/common/item_found_dialog.dart';
import 'base_scanner_mixin.dart';

/// Mixin providing standardized duplicate detection and handling
/// for scanner screens.
///
/// This mixin reduces code duplication by centralizing:
/// - Duplicate item detection logic
/// - Item found dialog flow
/// - Action handling (scanNext, addCopy, close)
/// - Automatic icon selection based on item type
///
/// Must be used in conjunction with BaseScannerMixin
mixin DuplicateCheckMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, BaseScannerMixin<T> {
  // This mixin enforces compile-time dependency on BaseScannerMixin

  /// Get the household ID for duplicate checking
  /// Must be implemented by the widget using this mixin
  String get householdId;

  /// Handle the duplicate item flow
  ///
  /// Shows the item found dialog and handles the user's choice:
  /// - 'scanNext': Reset scanning state, returns null
  /// - 'addCopy': Returns 'addCopy' to continue adding
  /// - 'close'/null: Reset scanning state, returns null
  ///
  /// Returns the action to take ('addCopy' or null)
  Future<String?> handleDuplicateFlow({
    required Item existingItem,
    String itemTypeName = 'Item',
  }) async {
    if (!mounted) return null;

    // Determine fallback icon based on item type
    final fallbackIcon = _getFallbackIcon(existingItem.type);

    // Load tracks for music items
    List<Track>? tracks;
    bool isLoadingTracks = false;

    if (ItemType.isMusicType(existingItem.type)) {
      tracks = existingItem.tracks; // Use cached tracks if available
      isLoadingTracks = tracks == null || tracks.isEmpty;

      // Load tracks asynchronously if not cached
      if (isLoadingTracks) {
        final trackService = ref.read(trackServiceProvider);
        try {
          tracks = await trackService.getTracksForItem(existingItem, householdId);
          isLoadingTracks = false;
        } catch (e) {
          isLoadingTracks = false;
          // Continue without tracks if loading fails
        }
      }
    }

    if (!mounted) return null;

    final action = await showItemFoundDialog(
      context: context,
      ref: ref,
      item: existingItem,
      householdId: householdId,
      itemTypeName: itemTypeName,
      fallbackIcon: fallbackIcon,
      showAddCopyOption: true,
      tracks: tracks,
      isLoadingTracks: isLoadingTracks,
    );

    if (!mounted) return null;

    if (action == 'scanNext' || action == null || action == 'close') {
      // Reset scanning state using BaseScannerMixin method
      resetScanning();
      return null;
    }

    // Return 'addCopy' to continue with adding the item
    return action;
  }

  /// Get the appropriate fallback icon for an item type
  IconData _getFallbackIcon(String? itemType) {
    switch (itemType) {
      case 'book':
        return Ionicons.book_outline;
      case 'music':
        return Ionicons.disc_outline;
      case 'game':
        return Ionicons.game_controller_outline;
      default:
        return Ionicons.cube_outline;
    }
  }
}
