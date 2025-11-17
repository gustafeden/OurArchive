import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item.dart';
import '../../../data/models/item_type.dart';
import '../../../providers/providers.dart';
import '../../../utils/icon_helper.dart';
import 'category_tab.dart';

/// Configuration for a category tab
class CategoryConfig {
  final String typeKey; // Internal type key (e.g., 'book', 'vinyl')
  final String label; // Display label (e.g., 'Books', 'Music')
  final VoidCallback? onTap; // Optional custom onTap (for special handling)

  const CategoryConfig({
    required this.typeKey,
    required this.label,
    this.onTap,
  });
}

/// A reusable widget for building category filter tabs with item counts.
///
/// This widget handles:
/// - Counting items by type
/// - Building tabs with labels and counts
/// - "All" tab for showing all items
/// - "Other" tab with dialog for non-primary types
/// - Integration with selectedTypeProvider for filtering
///
/// Supports two modes:
/// 1. Static mode: Uses predefined CategoryConfig list
/// 2. Dynamic mode: Fetches ItemType from provider (container_screen pattern)
class CategoryTabsBuilder extends ConsumerWidget {
  /// The list of items to count and filter
  final List<Item> items;

  /// The household ID (required for fetching dynamic item types)
  final String householdId;

  /// Primary category configurations (optional, uses defaults if not provided)
  /// If null, will fetch dynamically from itemTypesProvider
  final List<CategoryConfig>? staticCategories;

  /// Whether to use dynamic type fetching (default: false for static mode)
  final bool useDynamicTypes;

  const CategoryTabsBuilder({
    super.key,
    required this.items,
    required this.householdId,
    this.staticCategories,
    this.useDynamicTypes = false,
  });

  /// Factory for static mode with default categories
  factory CategoryTabsBuilder.static({
    required List<Item> items,
    required String householdId,
    VoidCallback? onMusicTap,
  }) {
    return CategoryTabsBuilder(
      items: items,
      householdId: householdId,
      staticCategories: [
        const CategoryConfig(typeKey: 'book', label: 'Books'),
        CategoryConfig(typeKey: 'vinyl', label: 'Music', onTap: onMusicTap),
        const CategoryConfig(typeKey: 'game', label: 'Games'),
        const CategoryConfig(typeKey: 'tool', label: 'Tools'),
      ],
      useDynamicTypes: false,
    );
  }

  /// Factory for dynamic mode (fetches from itemTypesProvider)
  factory CategoryTabsBuilder.dynamic({
    required List<Item> items,
    required String householdId,
  }) {
    return CategoryTabsBuilder(
      items: items,
      householdId: householdId,
      useDynamicTypes: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useDynamicTypes) {
      return _buildDynamicTabs(context, ref);
    } else {
      return _buildStaticTabs(context, ref);
    }
  }

  Widget _buildStaticTabs(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedTypeProvider);
    final categories = staticCategories ?? [];
    final primaryTypeKeys = categories.map((c) => c.typeKey).toList();

    // Count items for each category
    final counts = <String, int>{};
    for (var config in categories) {
      counts[config.typeKey] = items.where((i) => i.type == config.typeKey).length;
    }

    // Count "other" items
    final otherCount = items.where((i) => !primaryTypeKeys.contains(i.type)).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // "All" tab
          CategoryTab(
            label: 'All',
            count: items.length,
            isSelected: selectedType == null,
            onTap: () => ref.read(selectedTypeProvider.notifier).state = null,
          ),
          const SizedBox(width: 8),

          // Primary category tabs
          ...categories.map((config) {
            return [
              CategoryTab(
                label: config.label,
                count: counts[config.typeKey] ?? 0,
                isSelected: selectedType == config.typeKey,
                onTap: config.onTap ?? () {
                  ref.read(selectedTypeProvider.notifier).state = config.typeKey;
                },
              ),
              const SizedBox(width: 8),
            ];
          }).expand((widgets) => widgets),

          // "Other" tab
          if (otherCount > 0)
            CategoryTab(
              label: 'Other',
              count: otherCount,
              isSelected: selectedType != null && !primaryTypeKeys.contains(selectedType),
              onTap: () => _showOtherTypesDialog(context, ref, primaryTypeKeys),
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicTabs(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedTypeProvider);
    final itemTypesAsync = ref.watch(itemTypesProvider(householdId));

    return itemTypesAsync.when(
      loading: () => const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (itemTypes) {
        // Primary types to show as main tabs
        final primaryTypes = ['book', 'vinyl', 'game', 'tool', 'general'];

        // Count items for each primary type
        final typeCounts = <String, int>{};
        for (var type in primaryTypes) {
          typeCounts[type] = items.where((i) => i.type == type).length;
        }

        // Count items for "other" types
        final otherCount = items.where((i) => !primaryTypes.contains(i.type)).length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // "All" tab
              CategoryTab(
                label: 'All',
                count: items.length,
                isSelected: selectedType == null,
                onTap: () => ref.read(selectedTypeProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),

              // Build tabs for primary types
              ...primaryTypes.map((typeName) {
                final itemType = itemTypes.firstWhere(
                  (t) => t.name == typeName,
                  orElse: () => ItemType(
                    id: '',
                    name: typeName,
                    displayName: typeName,
                    icon: 'category',
                    isDefault: false,
                    hasSpecializedForm: false,
                    createdBy: '',
                    createdAt: DateTime.now(),
                  ),
                );

                return [
                  CategoryTab(
                    label: itemType.displayName,
                    count: typeCounts[typeName] ?? 0,
                    isSelected: selectedType == typeName,
                    onTap: () => ref.read(selectedTypeProvider.notifier).state = typeName,
                  ),
                  const SizedBox(width: 8),
                ];
              }).expand((widgets) => widgets),

              // "Other" tab
              if (otherCount > 0 || itemTypes.any((t) => !primaryTypes.contains(t.name)))
                CategoryTab(
                  label: 'Other',
                  count: otherCount,
                  isSelected: selectedType != null && !primaryTypes.contains(selectedType),
                  onTap: () => _showOtherTypesDialog(context, ref, primaryTypes),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showOtherTypesDialog(BuildContext context, WidgetRef ref, List<String> primaryTypes) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final itemTypesAsync = ref.watch(itemTypesProvider(householdId));

          return AlertDialog(
            title: const Text('Other Types'),
            content: itemTypesAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text('Error loading types: $error'),
              data: (itemTypes) {
                final otherTypes = itemTypes.where((t) => !primaryTypes.contains(t.name)).toList();

                if (otherTypes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No other types available'),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: otherTypes.map((type) {
                      return ListTile(
                        leading: Icon(IconHelper.getIconData(type.icon), size: 20),
                        title: Text(type.displayName),
                        onTap: () {
                          ref.read(selectedTypeProvider.notifier).state = type.name;
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }
}
