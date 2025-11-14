import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/item.dart';
import 'add_item_screen.dart';
import 'container_screen.dart';
import 'item_detail_screen.dart';

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
  @override
  void initState() {
    super.initState();
    // Set the current household when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentHouseholdIdProvider.notifier).state = widget.household.id;

      // Apply initial filter if provided
      if (widget.initialFilter == 'unorganized') {
        ref.read(selectedContainerFilterProvider.notifier).state = 'unorganized';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(householdItemsProvider);
    final filteredItems = ref.watch(filteredItemsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.currentUser!;
    final isOwner = widget.household.isOwner(currentUser.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.household.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2),
            tooltip: 'Organize',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContainerScreen(
                    householdId: widget.household.id,
                    householdName: widget.household.name,
                  ),
                ),
              );
            },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Show household code',
              onPressed: () {
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
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Filter chips
          _buildFilterChips(ref),

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

                return ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _ItemCard(item: item, household: widget.household);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemScreen(household: widget.household),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
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
    final types = ['general', 'tool', 'pantry', 'camera', 'book', 'vinyl', 'electronics', 'clothing', 'kitchen', 'outdoor'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: types.map((type) {
              return ListTile(
                title: Text(type[0].toUpperCase() + type.substring(1)),
                onTap: () {
                  ref.read(selectedTypeProvider.notifier).state = type;
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

  void _showContainerFilter(WidgetRef ref, List containers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                return ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(container.name),
                  subtitle: Text(container.containerType),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.type),
            if (item.location.isNotEmpty) Text('📍 ${item.location}'),
            if (item.quantity > 1) Text('Qty: ${item.quantity}'),
          ],
        ),
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
      ),
    );
  }

  Widget _buildThumbnail(WidgetRef ref) {
    if (item.photoThumbPath == null) {
      return CircleAvatar(
        child: Icon(_getIconForType()),
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
          child: Icon(_getIconForType()),
        );
      },
    );
  }

  IconData _getIconForType() {
    switch (item.type) {
      case 'book':
        return Icons.book;
      case 'tool':
        return Icons.build;
      case 'pantry':
        return Icons.restaurant;
      case 'camera':
        return Icons.camera_alt;
      case 'electronics':
        return Icons.devices;
      case 'clothing':
        return Icons.checkroom;
      case 'kitchen':
        return Icons.kitchen;
      case 'outdoor':
        return Icons.park;
      default:
        return Icons.inventory_2;
    }
  }
}
