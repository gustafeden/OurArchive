import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/item.dart';
import '../../data/models/item_type.dart';
import '../services/ui_service.dart';
import 'item_type_selection_screen.dart';
import 'book_scan_screen.dart';
import 'music_scan_screen.dart';
import 'container_screen.dart';
import 'manage_types_screen.dart';
import 'common/scan_modes.dart';
import 'book_grid_browser.dart';
import '../../utils/icon_helper.dart';
import '../widgets/common/category_tabs_builder.dart';
import '../widgets/common/item_card_widget.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/common/item_list_view.dart';

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
      extendBody: true,
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
            icon: Icon(_isSearching ? Ionicons.close_outline : Ionicons.search_outline),
            tooltip: _isSearching ? 'Close search' : 'Search items',
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
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'view_mode') {
                ref.read(viewModeProvider.notifier).state =
                    viewMode == ViewMode.list ? ViewMode.browse : ViewMode.list;
              } else if (value == 'organize') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/container'),
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
                                icon: const Icon(Ionicons.copy_outline),
                                tooltip: 'Copy household code',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: widget.household.code),
                                  );
                                  UiService.showSuccess('Code copied!');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      FilledButton(
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
                      viewMode == ViewMode.list ? Ionicons.grid_outline : Ionicons.list_outline,
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
                    Icon(Ionicons.cube_outline, size: 20),
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
                    Icon(Ionicons.apps_outline, size: 20),
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
                      Icon(Ionicons.qr_code_outline, size: 20),
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
            CategoryTabsBuilder.static(
              items: filteredItems,
              householdId: widget.household.id,
              onBooksTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/books'),
                    builder: (context) => BookGridBrowser(
                      householdId: widget.household.id,
                    ),
                  ),
                );
              },
              onMusicTap: () {
                ref.read(selectedTypeProvider.notifier).state = 'music';
                ref.read(selectedMusicFormatProvider.notifier).state = null;
              },
            ),

          // Music sub-category filter (show only when Music tab is selected)
          if (viewMode == ViewMode.list && ItemType.isMusicType(selectedType))
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
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(householdItemsProvider);
                      await ref.read(householdItemsProvider.future);
                    },
                    child: EmptyStateWidget(
                      icon: searchQuery.isNotEmpty ? Ionicons.close_circle_outline : Ionicons.cube_outline,
                      title: searchQuery.isNotEmpty ? 'No items found' : 'No items yet',
                      subtitle: searchQuery.isNotEmpty
                          ? 'Try a different search term'
                          : 'Tap + to add your first item',
                    ),
                  );
                }

                // Browse mode or grouped list mode: use ItemListView
                if (viewMode == ViewMode.browse || selectedType == null) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(householdItemsProvider);
                      await ref.read(householdItemsProvider.future);
                    },
                    child: ItemListView(
                      items: filteredItems,
                      household: widget.household,
                      viewMode: viewMode,
                      showSyncStatus: true,
                      showLocationInSubtitle: true,
                    ),
                  );
                } else {
                  // Flat list when specific type is selected
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(householdItemsProvider);
                      await ref.read(householdItemsProvider.future);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ItemCardWidget(
                          item: item,
                          household: widget.household,
                          showSyncStatus: true,
                          showLocationInSubtitle: true,
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'item_list_fab',
        onPressed: () => _showAddItemSheet(context),
        tooltip: 'Add item',
        child: const Icon(Ionicons.add_outline),
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Add Item',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              // Quick scan options
              _buildAddOption(
                context,
                icon: Ionicons.scan_outline,
                iconColor: Colors.blue,
                title: 'Scan Book',
                subtitle: 'Scan ISBN barcode',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookScanScreen(
                        householdId: widget.household.id,
                        initialMode: ScanMode.camera,
                      ),
                    ),
                  );
                },
              ),
              _buildAddOption(
                context,
                icon: Ionicons.disc_outline,
                iconColor: Colors.purple,
                title: 'Scan Music',
                subtitle: 'Scan album barcode',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MusicScanScreen(
                        householdId: widget.household.id,
                        initialMode: ScanMode.camera,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              _buildAddOption(
                context,
                icon: Ionicons.create_outline,
                iconColor: Colors.grey[600]!,
                title: 'Add Manually',
                subtitle: 'Choose item type and enter details',
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      trailing: Icon(Ionicons.chevron_forward_outline, color: Colors.grey[400], size: 20),
      onTap: onTap,
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

  Widget _buildMusicFormatFilter(WidgetRef ref, List<Item> allItems) {
    final selectedMusicFormat = ref.watch(selectedMusicFormatProvider);

    // Count items by music format
    final cdCount = allItems.where((i) => ItemType.isMusicType(i.type) && _getMusicSubType(i) == 'music-cd').length;
    final musicCount = allItems.where((i) => ItemType.isMusicType(i.type) && _getMusicSubType(i) == 'music-vinyl').length;
    final cassetteCount = allItems.where((i) => ItemType.isMusicType(i.type) && _getMusicSubType(i) == 'music-cassette').length;
    final digitalCount = allItems.where((i) => ItemType.isMusicType(i.type) && _getMusicSubType(i) == 'music-digital').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MusicFormatChip(
              label: 'All Music',
              count: allItems.where((i) => ItemType.isMusicType(i.type)).length,
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
            if (musicCount > 0) ...[
              _MusicFormatChip(
                label: 'Vinyl',
                count: musicCount,
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
              icon: Ionicons.apps_outline,
              label: 'Type',
              onPressed: () => _showTypeFilter(ref),
            ),
            const SizedBox(width: 8),
            _FilterButton(
              icon: Ionicons.cube_outline,
              label: 'Container',
              onPressed: () => _showContainerFilter(ref, allContainers),
            ),
            const SizedBox(width: 8),
            _FilterButton(
              icon: Ionicons.pricetag_outline,
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
              avatar: const Icon(Ionicons.apps_outline, size: 18),
            ),
          if (selectedContainer != null)
            FilterChip(
              label: Text('Container: ${_getContainerName(allContainers, selectedContainer)}'),
              onSelected: (value) => ref.read(selectedContainerFilterProvider.notifier).state = null,
              selected: true,
              onDeleted: () => ref.read(selectedContainerFilterProvider.notifier).state = null,
              avatar: const Icon(Ionicons.cube_outline, size: 18),
            ),
          if (selectedTag != null)
            FilterChip(
              label: Text('Tag: $selectedTag'),
              onSelected: (value) => ref.read(selectedTagFilterProvider.notifier).state = null,
              selected: true,
              onDeleted: () => ref.read(selectedTagFilterProvider.notifier).state = null,
              avatar: const Icon(Ionicons.pricetag_outline, size: 18),
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
                    leading: const Icon(Ionicons.mail_outline),
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
                      leading: const Icon(Ionicons.cube_outline),
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
      UiService.showInfo('No tags found in items');
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
                leading: const Icon(Ionicons.pricetag_outline),
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
    return Tooltip(
      message: 'Filter by $label',
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

