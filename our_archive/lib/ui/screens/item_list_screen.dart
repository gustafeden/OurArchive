import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/item.dart';
import 'item_type_selection_screen.dart';
import 'book_scan_screen.dart';
import 'vinyl_scan_screen.dart';
import 'container_screen.dart';
import 'item_detail_screen.dart';
import 'manage_types_screen.dart';
import '../../utils/icon_helper.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  final Household household;
  final String? initialFilter;

  const ItemListScreen({
    super.key,
    required this.household,
    this.initialFilter,
  });

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set the current household when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentHouseholdIdProvider.notifier).state = widget.household.id;

      // Apply initial filter if provided, otherwise clear filters
      if (widget.initialFilter == 'unorganized') {
        ref.read(selectedContainerFilterProvider.notifier).state = 'unorganized';
      } else if (widget.initialFilter == null) {
        // Clear all filters when entering without a specific filter
        // This ensures newly added items are visible
        ref.read(selectedContainerFilterProvider.notifier).state = null;
        ref.read(selectedTypeProvider.notifier).state = null;
        ref.read(selectedTagFilterProvider.notifier).state = null;
        ref.read(selectedMusicFormatProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(householdItemsProvider);
    final filteredItems = ref.watch(filteredItemsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedType = ref.watch(selectedTypeProvider);
    final viewMode = ref.watch(viewModeProvider);
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.currentUser!;
    final isOwner = widget.household.isOwner(currentUser.uid);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
              )
            : Text(widget.household.name),
        actions: [
          // Search button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
          // Three-dot menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'view_mode') {
                ref.read(viewModeProvider.notifier).state =
                    viewMode == ViewMode.list ? ViewMode.browse : ViewMode.list;
              } else if (value == 'organize') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContainerScreen(
                      householdId: widget.household.id,
                      householdName: widget.household.name,
                    ),
                  ),
                );
              } else if (value == 'manage_types') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageTypesScreen(
                      householdId: widget.household.id,
                    ),
                  ),
                );
              } else if (value == 'household_code') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Household Code'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Share this code with family members:'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.household.code,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: widget.household.code),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Code copied!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view_mode',
                child: Row(
                  children: [
                    Icon(
                      viewMode == ViewMode.list ? Icons.dashboard_outlined : Icons.list,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(viewMode == ViewMode.list ? 'Browse Mode' : 'List Mode'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'organize',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, size: 20),
                    SizedBox(width: 8),
                    Text('Organize'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'manage_types',
                child: Row(
                  children: [
                    Icon(Icons.category, size: 20),
                    SizedBox(width: 8),
                    Text('Manage Types'),
                  ],
                ),
              ),
              if (isOwner) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'household_code',
                  child: Row(
                    children: [
                      Icon(Icons.qr_code, size: 20),
                      SizedBox(width: 8),
                      Text('Household Code'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(ref),

          // Category tabs (hide in browse mode)
          if (viewMode == ViewMode.list)
            _buildCategoryTabs(ref, filteredItems),

          // Music sub-category filter (show only when Music tab is selected)
          if (viewMode == ViewMode.list && selectedType == 'vinyl')
            _buildMusicFormatFilter(ref, filteredItems),

          // Items list
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
              data: (items) {
                // Use the filtered items from filteredItemsProvider
                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty ? 'No items found' : 'No items yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Try a different search term'
                              : 'Tap + to add your first item',
                        ),
                      ],
                    ),
                  );
                }

                // Browse mode: show collapsible category sections
                if (viewMode == ViewMode.browse) {
                  return _buildBrowseView(filteredItems);
                }

                // List mode: show grouped when "All" selected, flat list otherwise
                if (selectedType == null) {
                  return _buildGroupedItemList(filteredItems);
                } else {
                  return ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _ItemCard(item: item, household: widget.household);
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () {
          _showQuickAddMenu(context);
        },
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemTypeSelectionScreen(
                  householdId: widget.household.id,
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
        ),
      ),
    );
  }

  void _showQuickAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.blue),
              ),
              title: const Text('Scan Book'),
              subtitle: const Text('Quick scan ISBN barcode'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookScanScreen(
                      householdId: widget.household.id,
                      initialMode: BookScanMode.camera,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.album, color: Colors.purple),
              ),
              title: const Text('Scan Music'),
              subtitle: const Text('Quick scan music barcode'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VinylScanScreen(
                      householdId: widget.household.id,
                      initialMode: VinylScanMode.camera,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Show All Options'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemTypeSelectionScreen(
                      householdId: widget.household.id,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedItemList(List<Item> items) {
    // Group items by type, but split vinyl into music sub-types
    final groupedItems = <String, List<Item>>{};
    final categoryOrder = ['book', 'music-cd', 'music-vinyl', 'music-cassette', 'music-digital', 'music-other', 'game', 'tool', 'pantry', 'camera', 'electronics', 'clothing', 'kitchen', 'outdoor', 'general'];

    for (final item in items) {
      if (item.type == 'vinyl') {
        // Split vinyl items by format
        final subType = _getMusicSubType(item);
        groupedItems.putIfAbsent(subType, () => []).add(item);
      } else {
        groupedItems.putIfAbsent(item.type, () => []).add(item);
      }
    }

    // Sort categories by predefined order, then alphabetically for others
    final sortedTypes = groupedItems.keys.toList()..sort((a, b) {
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
        String typeLabel;
        if (type.startsWith('music-')) {
          switch (type) {
            case 'music-cd':
              typeLabel = 'CD';
              break;
            case 'music-vinyl':
              typeLabel = 'Vinyl';
              break;
            case 'music-cassette':
              typeLabel = 'Cassette';
              break;
            case 'music-digital':
              typeLabel = 'Digital';
              break;
            case 'music-other':
              typeLabel = 'Music (Other)';
              break;
            default:
              typeLabel = 'Music';
          }
        } else {
          typeLabel = type[0].toUpperCase() + type.substring(1);
        }

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
            ...typeItems.map((item) => _ItemCard(item: item, household: widget.household)),
            if (sectionIndex < sortedTypes.length - 1)
              const Divider(height: 1, thickness: 1),
          ],
        );
      },
    );
  }

  Widget _buildBrowseView(List<Item> items) {
    // Group items by type, but split vinyl into music sub-types
    final groupedItems = <String, List<Item>>{};
    final categoryOrder = ['book', 'music-cd', 'music-vinyl', 'music-cassette', 'music-digital', 'music-other', 'game', 'tool', 'pantry', 'camera', 'electronics', 'clothing', 'kitchen', 'outdoor', 'general'];

    for (final item in items) {
      if (item.type == 'vinyl') {
        // Split vinyl items by format
        final subType = _getMusicSubType(item);
        groupedItems.putIfAbsent(subType, () => []).add(item);
      } else {
        groupedItems.putIfAbsent(item.type, () => []).add(item);
      }
    }

    // Sort categories by predefined order
    final sortedTypes = groupedItems.keys.toList()..sort((a, b) {
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
        String typeLabel;
        if (type.startsWith('music-')) {
          switch (type) {
            case 'music-cd':
              typeLabel = 'CD';
              break;
            case 'music-vinyl':
              typeLabel = 'Vinyl';
              break;
            case 'music-cassette':
              typeLabel = 'Cassette';
              break;
            case 'music-digital':
              typeLabel = 'Digital';
              break;
            case 'music-other':
              typeLabel = 'Music (Other)';
              break;
            default:
              typeLabel = 'Music';
          }
        } else {
          typeLabel = type[0].toUpperCase() + type.substring(1);
        }

        final isExpanded = expandedCategories.contains(type);

        return _CollapsibleCategorySection(
          type: type,
          typeLabel: typeLabel,
          icon: IconHelper.getItemIcon(type),
          itemCount: typeItems.length,
          isExpanded: isExpanded,
          items: typeItems,
          household: widget.household,
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


  Widget _buildCategoryTabs(WidgetRef ref, List<Item> allItems) {
    final selectedType = ref.watch(selectedTypeProvider);

    // Count items by type
    final bookCount = allItems.where((i) => i.type == 'book').length;
    final vinylCount = allItems.where((i) => i.type == 'vinyl').length;
    final gameCount = allItems.where((i) => i.type == 'game').length;
    final toolCount = allItems.where((i) => i.type == 'tool').length;
    final otherCount = allItems.where((i) => !['book', 'vinyl', 'game', 'tool'].contains(i.type)).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _CategoryTab(
            label: 'All',
            count: allItems.length,
            isSelected: selectedType == null,
            onTap: () => ref.read(selectedTypeProvider.notifier).state = null,
          ),
          const SizedBox(width: 8),
          _CategoryTab(
            label: 'Books',
            count: bookCount,
            isSelected: selectedType == 'book',
            onTap: () => ref.read(selectedTypeProvider.notifier).state = 'book',
          ),
          const SizedBox(width: 8),
          _CategoryTab(
            label: 'Music',
            count: vinylCount,
            isSelected: selectedType == 'vinyl',
            onTap: () {
              ref.read(selectedTypeProvider.notifier).state = 'vinyl';
              ref.read(selectedMusicFormatProvider.notifier).state = null;
            },
          ),
          const SizedBox(width: 8),
          _CategoryTab(
            label: 'Games',
            count: gameCount,
            isSelected: selectedType == 'game',
            onTap: () => ref.read(selectedTypeProvider.notifier).state = 'game',
          ),
          const SizedBox(width: 8),
          _CategoryTab(
            label: 'Tools',
            count: toolCount,
            isSelected: selectedType == 'tool',
            onTap: () => ref.read(selectedTypeProvider.notifier).state = 'tool',
          ),
          const SizedBox(width: 8),
          _CategoryTab(
            label: 'Other',
            count: otherCount,
            isSelected: selectedType != null && !['book', 'vinyl', 'game', 'tool'].contains(selectedType),
            onTap: () => _showOtherTypesDialog(ref),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicFormatFilter(WidgetRef ref, List<Item> allItems) {
    final selectedMusicFormat = ref.watch(selectedMusicFormatProvider);

    // Count items by music format
    final cdCount = allItems.where((i) => i.type == 'vinyl' && _getMusicSubType(i) == 'music-cd').length;
    final vinylCount = allItems.where((i) => i.type == 'vinyl' && _getMusicSubType(i) == 'music-vinyl').length;
    final cassetteCount = allItems.where((i) => i.type == 'vinyl' && _getMusicSubType(i) == 'music-cassette').length;
    final digitalCount = allItems.where((i) => i.type == 'vinyl' && _getMusicSubType(i) == 'music-digital').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MusicFormatChip(
              label: 'All Music',
              count: allItems.where((i) => i.type == 'vinyl').length,
              isSelected: selectedMusicFormat == null,
              onTap: () => ref.read(selectedMusicFormatProvider.notifier).state = null,
            ),
            const SizedBox(width: 8),
            if (cdCount > 0) ...[
              _MusicFormatChip(
                label: 'CD',
                count: cdCount,
                isSelected: selectedMusicFormat == 'cd',
                onTap: () => ref.read(selectedMusicFormatProvider.notifier).state = 'cd',
              ),
              const SizedBox(width: 8),
            ],
            if (vinylCount > 0) ...[
              _MusicFormatChip(
                label: 'Vinyl',
                count: vinylCount,
                isSelected: selectedMusicFormat == 'vinyl',
                onTap: () => ref.read(selectedMusicFormatProvider.notifier).state = 'vinyl',
              ),
              const SizedBox(width: 8),
            ],
            if (cassetteCount > 0) ...[
              _MusicFormatChip(
                label: 'Cassette',
                count: cassetteCount,
                isSelected: selectedMusicFormat == 'cassette',
                onTap: () => ref.read(selectedMusicFormatProvider.notifier).state = 'cassette',
              ),
              const SizedBox(width: 8),
            ],
            if (digitalCount > 0) ...[
              _MusicFormatChip(
                label: 'Digital',
                count: digitalCount,
                isSelected: selectedMusicFormat == 'digital',
                onTap: () => ref.read(selectedMusicFormatProvider.notifier).state = 'digital',
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOtherTypesDialog(WidgetRef ref) {
    final primaryTypes = ['book', 'vinyl', 'game', 'tool'];

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final itemTypesAsync = ref.watch(itemTypesProvider(widget.household.id));

          return AlertDialog(
            title: const Text('Other Types'),
            content: itemTypesAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text('Error loading types: $error'),
              data: (itemTypes) {
                // Get all types that are not in the primary list
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

  Widget _buildFilterChips(WidgetRef ref) {
    final selectedType = ref.watch(selectedTypeProvider);
    final selectedContainer = ref.watch(selectedContainerFilterProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final allContainers = ref.watch(allContainersProvider).value ?? [];
    final allTags = ref.watch(allTagsProvider);

    final hasActiveFilters = selectedType != null || selectedContainer != null || selectedTag != null;

    if (!hasActiveFilters) {
      // Show filter buttons only
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _FilterButton(
              icon: Icons.category,
              label: 'Type',
              onPressed: () => _showTypeFilter(ref),
            ),
            const SizedBox(width: 8),
            _FilterButton(
              icon: Icons.inventory_2,
              label: 'Container',
              onPressed: () => _showContainerFilter(ref, allContainers),
            ),
            const SizedBox(width: 8),
            _FilterButton(
              icon: Icons.label,
              label: 'Tag',
              onPressed: () => _showTagFilter(ref, allTags),
            ),
          ],
        ),
      );
    }

    // Show active filter chips
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (selectedType != null)
            FilterChip(
              label: Text('Type: $selectedType'),
              onSelected: (value) => ref.read(selectedTypeProvider.notifier).state = null,
              selected: true,
              onDeleted: () => ref.read(selectedTypeProvider.notifier).state = null,
              avatar: const Icon(Icons.category, size: 18),
            ),
          if (selectedContainer != null)
            FilterChip(
              label: Text('Container: ${_getContainerName(allContainers, selectedContainer)}'),
              onSelected: (value) => ref.read(selectedContainerFilterProvider.notifier).state = null,
              selected: true,
              onDeleted: () => ref.read(selectedContainerFilterProvider.notifier).state = null,
              avatar: const Icon(Icons.inventory_2, size: 18),
            ),
          if (selectedTag != null)
            FilterChip(
              label: Text('Tag: $selectedTag'),
              onSelected: (value) => ref.read(selectedTagFilterProvider.notifier).state = null,
              selected: true,
              onDeleted: () => ref.read(selectedTagFilterProvider.notifier).state = null,
              avatar: const Icon(Icons.label, size: 18),
            ),
          // Clear all button
          ActionChip(
            label: const Text('Clear all'),
            onPressed: () {
              ref.read(selectedTypeProvider.notifier).state = null;
              ref.read(selectedContainerFilterProvider.notifier).state = null;
              ref.read(selectedTagFilterProvider.notifier).state = null;
              ref.read(selectedMusicFormatProvider.notifier).state = null;
            },
          ),
        ],
      ),
    );
  }

  String _getContainerName(List containers, String containerId) {
    if (containerId == 'unorganized') {
      return 'Unorganized';
    }
    try {
      final container = containers.firstWhere((c) => c.id == containerId);
      return container.name;
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showTypeFilter(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final itemTypesAsync = ref.watch(itemTypesProvider(widget.household.id));

          return AlertDialog(
            title: const Text('Filter by Type'),
            content: itemTypesAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text('Error loading types: $error'),
              data: (itemTypes) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: itemTypes.map((type) {
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

  void _showContainerFilter(WidgetRef ref, List containers) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final containerTypesAsync = ref.watch(containerTypesProvider(widget.household.id));

          return AlertDialog(
            title: const Text('Filter by Container'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.inbox),
                    title: const Text('Unorganized Items'),
                    onTap: () {
                      ref.read(selectedContainerFilterProvider.notifier).state = 'unorganized';
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ...containers.map((container) {
                    // Get display name from containerTypesProvider
                    String typeDisplayName = container.containerType;
                    containerTypesAsync.whenData((types) {
                      final matchingType = types.where((t) => t.name == container.containerType).firstOrNull;
                      if (matchingType != null) {
                        typeDisplayName = matchingType.displayName;
                      }
                    });

                    return ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: Text(container.name),
                      subtitle: Text(typeDisplayName),
                      onTap: () {
                        ref.read(selectedContainerFilterProvider.notifier).state = container.id;
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
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

  void _showTagFilter(WidgetRef ref, List<String> tags) {
    if (tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tags found in items')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Tag'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tags.map((tag) {
              return ListTile(
                leading: const Icon(Icons.label),
                title: Text(tag),
                onTap: () {
                  ref.read(selectedTagFilterProvider.notifier).state = tag;
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final Item item;
  final Household household;

  const _ItemCard({required this.item, required this.household});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildThumbnail(ref),
        title: Text(item.title),
        subtitle: _buildSubtitle(),
        trailing: item.syncStatus != SyncStatus.synced
            ? const Icon(Icons.sync, size: 16)
            : null,
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
        // Generic items show type and quantity
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.type),
            if (item.location.isNotEmpty) Text('📍 ${item.location}'),
            if (item.quantity > 1) Text('Qty: ${item.quantity}'),
          ],
        );
    }
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

}

class _CategoryTab extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicFormatChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _MusicFormatChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
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
  final VoidCallback onToggle;

  const _CollapsibleCategorySection({
    required this.type,
    required this.typeLabel,
    required this.icon,
    required this.itemCount,
    required this.isExpanded,
    required this.items,
    required this.household,
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
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          ...items.map((item) => _ItemCard(item: item, household: household)),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}
