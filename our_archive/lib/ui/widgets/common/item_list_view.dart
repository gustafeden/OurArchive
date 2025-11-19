import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../data/models/item.dart';
import '../../../data/models/item_type.dart';
import '../../../data/models/household.dart';
import '../../../providers/providers.dart';
import '../../../utils/icon_helper.dart';
import 'item_card_widget.dart';

/// A reusable widget for displaying items in either list or browse mode
class ItemListView extends ConsumerWidget {
  final List<Item> items;
  final Household household;
  final ViewMode viewMode;
  final bool showSyncStatus;
  final bool showLocationInSubtitle;
  final bool showEditActions;
  final Function(Item)? onMoveItem;
  final Function(Item)? onDeleteItem;

  const ItemListView({
    super.key,
    required this.items,
    required this.household,
    required this.viewMode,
    this.showSyncStatus = false,
    this.showLocationInSubtitle = false,
    this.showEditActions = false,
    this.onMoveItem,
    this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No items to display'),
      );
    }

    // Browse mode: show collapsible category sections
    if (viewMode == ViewMode.browse) {
      return _buildBrowseView(context, ref);
    }

    // List mode: show grouped items
    return _buildGroupedItemList(context, ref);
  }

  Widget _buildGroupedItemList(BuildContext context, WidgetRef ref) {
    // Group items by type, but split vinyl into music sub-types
    final groupedItems = <String, List<Item>>{};
    final categoryOrder = [
      'book',
      'music-cd',
      'music-vinyl',
      'music-cassette',
      'music-digital',
      'music-other',
      'game',
      'tool',
      'pantry',
      'camera',
      'electronics',
      'clothing',
      'kitchen',
      'outdoor',
      'general'
    ];

    for (final item in items) {
      if (ItemType.isMusicType(item.type)) {
        // Split music items by format
        final subType = _getMusicSubType(item);
        groupedItems.putIfAbsent(subType, () => []).add(item);
      } else {
        groupedItems.putIfAbsent(item.type, () => []).add(item);
      }
    }

    // Sort categories by predefined order, then alphabetically for others
    final sortedTypes = groupedItems.keys.toList()
      ..sort((a, b) {
        final aIndex = categoryOrder.indexOf(a);
        final bIndex = categoryOrder.indexOf(b);
        if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;
        return a.compareTo(b);
      });

    return ListView.builder(
      itemCount: sortedTypes.length,
      itemBuilder: (context, sectionIndex) {
        final type = sortedTypes[sectionIndex];
        final typeItems = groupedItems[type]!;

        // Custom labels for music sub-types
        final typeLabel = _getTypeLabel(type);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(IconHelper.getItemIcon(type), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$typeLabel (${typeItems.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            ...typeItems.map((item) => ItemCardWidget(
                  item: item,
                  household: household,
                  showSyncStatus: showSyncStatus,
                  showLocationInSubtitle: showLocationInSubtitle,
                  showEditActions: showEditActions,
                  onMoveItem: onMoveItem != null ? () => onMoveItem!(item) : null,
                  onDeleteItem: onDeleteItem != null ? () => onDeleteItem!(item) : null,
                )),
            if (sectionIndex < sortedTypes.length - 1) const Divider(height: 1, thickness: 1),
          ],
        );
      },
    );
  }

  Widget _buildBrowseView(BuildContext context, WidgetRef ref) {
    // Group items by type, but split vinyl into music sub-types
    final groupedItems = <String, List<Item>>{};
    final categoryOrder = [
      'book',
      'music-cd',
      'music-vinyl',
      'music-cassette',
      'music-digital',
      'music-other',
      'game',
      'tool',
      'pantry',
      'camera',
      'electronics',
      'clothing',
      'kitchen',
      'outdoor',
      'general'
    ];

    for (final item in items) {
      if (ItemType.isMusicType(item.type)) {
        // Split music items by format
        final subType = _getMusicSubType(item);
        groupedItems.putIfAbsent(subType, () => []).add(item);
      } else {
        groupedItems.putIfAbsent(item.type, () => []).add(item);
      }
    }

    // Sort categories by predefined order
    final sortedTypes = groupedItems.keys.toList()
      ..sort((a, b) {
        final aIndex = categoryOrder.indexOf(a);
        final bIndex = categoryOrder.indexOf(b);
        if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;
        return a.compareTo(b);
      });

    final expandedCategories = ref.watch(expandedCategoriesProvider);

    return ListView.builder(
      itemCount: sortedTypes.length,
      itemBuilder: (context, index) {
        final type = sortedTypes[index];
        final typeItems = groupedItems[type]!;

        // Custom labels for music sub-types
        final typeLabel = _getTypeLabel(type);

        final isExpanded = expandedCategories.contains(type);

        return _CollapsibleCategorySection(
          type: type,
          typeLabel: typeLabel,
          icon: IconHelper.getItemIcon(type),
          itemCount: typeItems.length,
          isExpanded: isExpanded,
          items: typeItems,
          household: household,
          showSyncStatus: showSyncStatus,
          showLocationInSubtitle: showLocationInSubtitle,
          showEditActions: showEditActions,
          onMoveItem: onMoveItem,
          onDeleteItem: onDeleteItem,
          onToggle: () {
            final newExpanded = Set<String>.from(expandedCategories);
            if (isExpanded) {
              newExpanded.remove(type);
            } else {
              newExpanded.add(type);
            }
            ref.read(expandedCategoriesProvider.notifier).state = newExpanded;
          },
        );
      },
    );
  }

  String _getMusicSubType(Item item) {
    if (item.format == null || item.format!.isEmpty) return 'music-other';
    final formatStr = item.format!.join(' ').toLowerCase();
    if (formatStr.contains('cd')) return 'music-cd';
    if (formatStr.contains('vinyl') || formatStr.contains('lp')) return 'music-vinyl';
    if (formatStr.contains('cassette')) return 'music-cassette';
    if (formatStr.contains('digital') || formatStr.contains('file')) return 'music-digital';
    return 'music-other';
  }

  String _getTypeLabel(String type) {
    if (type.startsWith('music-')) {
      switch (type) {
        case 'music-cd':
          return 'CD';
        case 'music-vinyl':
          return 'Vinyl';
        case 'music-cassette':
          return 'Cassette';
        case 'music-digital':
          return 'Digital';
        case 'music-other':
          return 'Music (Other)';
        default:
          return 'Music';
      }
    } else {
      return type[0].toUpperCase() + type.substring(1);
    }
  }
}

class _CollapsibleCategorySection extends StatelessWidget {
  final String type;
  final String typeLabel;
  final IconData icon;
  final int itemCount;
  final bool isExpanded;
  final List<Item> items;
  final Household household;
  final bool showSyncStatus;
  final bool showLocationInSubtitle;
  final bool showEditActions;
  final Function(Item)? onMoveItem;
  final Function(Item)? onDeleteItem;
  final VoidCallback onToggle;

  const _CollapsibleCategorySection({
    required this.type,
    required this.typeLabel,
    required this.icon,
    required this.itemCount,
    required this.isExpanded,
    required this.items,
    required this.household,
    required this.showSyncStatus,
    required this.showLocationInSubtitle,
    required this.showEditActions,
    this.onMoveItem,
    this.onDeleteItem,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$typeLabel ($itemCount)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Ionicons.chevron_up_outline : Ionicons.chevron_down_outline,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          ...items.map((item) => ItemCardWidget(
                item: item,
                household: household,
                showSyncStatus: showSyncStatus,
                showLocationInSubtitle: showLocationInSubtitle,
                showEditActions: showEditActions,
                onMoveItem: onMoveItem != null ? () => onMoveItem!(item) : null,
                onDeleteItem: onDeleteItem != null ? () => onDeleteItem!(item) : null,
              )),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}
