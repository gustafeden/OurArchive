import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/providers.dart';
import '../../data/models/container.dart' as model;
import '../../data/models/item.dart';
import '../../data/models/household.dart';
import 'item_type_selection_screen.dart';
import 'barcode_scan_screen.dart';
import 'item_detail_screen.dart';
import 'item_list_screen.dart';
import 'book_scan_screen.dart';
import 'vinyl_scan_screen.dart';

class ContainerScreen extends ConsumerStatefulWidget {
  final String householdId;
  final String householdName;
  final String? parentContainerId; // null for top-level (rooms)
  final List<model.Container> breadcrumb; // Path from root to current

  const ContainerScreen({
    super.key,
    required this.householdId,
    required this.householdName,
    this.parentContainerId,
    this.breadcrumb = const [],
  });

  @override
  ConsumerState<ContainerScreen> createState() => _ContainerScreenState();
}

class _ContainerScreenState extends ConsumerState<ContainerScreen> {
  bool _isEditMode = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get containers: top-level if parentContainerId is null, otherwise children
    final containersAsync = widget.parentContainerId == null
        ? ref.watch(householdContainersProvider)
        : ref.watch(childContainersProvider(widget.parentContainerId!));

    // Get items based on toggle state (nested vs direct only)
    final showNested = ref.watch(showNestedItemsProvider);
    final selectedType = ref.watch(selectedTypeProvider);
    final itemsAsync = showNested
        ? ref.watch(nestedContainerItemsProvider(widget.parentContainerId))
        : ref.watch(containerItemsProvider(widget.parentContainerId));

    final title = widget.breadcrumb.isEmpty ? widget.householdName : widget.breadcrumb.last.name;

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
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (widget.breadcrumb.isNotEmpty)
                    Text(
                      _getBreadcrumbText(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                ],
              ),
        actions: [
          // Search button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          // Three-dot menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                setState(() {
                  _isEditMode = !_isEditMode;
                });
              } else if (value == 'direct_items') {
                ref.read(showNestedItemsProvider.notifier).state = false;
              } else if (value == 'nested_items') {
                ref.read(showNestedItemsProvider.notifier).state = true;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(_isEditMode ? Icons.done : Icons.edit, size: 20),
                    const SizedBox(width: 8),
                    Text(_isEditMode ? 'Done Editing' : 'Edit Mode'),
                  ],
                ),
              ),
              if (widget.breadcrumb.isNotEmpty) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'direct_items',
                  child: Row(
                    children: [
                      Icon(Icons.unfold_less,
                          size: 20, color: !showNested ? Theme.of(context).colorScheme.primary : null),
                      const SizedBox(width: 8),
                      Text('Direct items only',
                          style: TextStyle(fontWeight: !showNested ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'nested_items',
                  child: Row(
                    children: [
                      Icon(Icons.unfold_more,
                          size: 20, color: showNested ? Theme.of(context).colorScheme.primary : null),
                      const SizedBox(width: 8),
                      Text('All nested items',
                          style: TextStyle(fontWeight: showNested ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: containersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (containers) {
          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (items) {
              final hasContent = containers.isNotEmpty || items.isNotEmpty;

              if (!hasContent) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.breadcrumb.isEmpty ? 'No rooms yet' : 'Empty',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.breadcrumb.isEmpty
                            ? 'Create your first room to get organized'
                            : 'Add containers or items here',
                      ),
                    ],
                  ),
                );
              }

              // Filter items by selected type and search query
              var filteredItems =
                  selectedType == null ? items : items.where((item) => item.type == selectedType).toList();

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                filteredItems = filteredItems.where((item) {
                  return item.title.toLowerCase().contains(_searchQuery) ||
                      (item.authors?.any((author) => author.toLowerCase().contains(_searchQuery)) ?? false) ||
                      (item.artist?.toLowerCase().contains(_searchQuery) ?? false) ||
                      (item.platform?.toLowerCase().contains(_searchQuery) ?? false) ||
                      item.type.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              // Filter containers by search query
              var filteredContainers = containers;
              if (_searchQuery.isNotEmpty) {
                filteredContainers = containers.where((container) {
                  return container.name.toLowerCase().contains(_searchQuery) ||
                      container.containerType.toLowerCase().contains(_searchQuery) ||
                      (container.description?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();
              }

              return Column(
                children: [
                  // Category tabs (only show if there are items)
                  if (items.isNotEmpty) _buildCategoryTabs(ref, items),

                  // Content list
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredContainers.length + (filteredItems.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show items section first if we have unorganized items at top level
                        if (widget.breadcrumb.isEmpty && filteredItems.isNotEmpty && index == 0) {
                          return _buildUnorganizedItemsCard(context, ref, filteredItems);
                        }

                        // Adjust index if we showed items card first
                        final containerIndex =
                            (widget.breadcrumb.isEmpty && filteredItems.isNotEmpty) ? index - 1 : index;

                        // Show items at the end for non-top-level
                        if (containerIndex >= filteredContainers.length) {
                          return Column(
                            children: filteredItems.map((item) => _buildItemCard(context, ref, item)).toList(),
                          );
                        }

                        final container = filteredContainers[containerIndex];
                        return _buildContainerCard(context, ref, container);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onLongPress: () => _showQuickAddMenu(context),
            child: FloatingActionButton.extended(
              heroTag: 'add_item',
              onPressed: () => _navigateToAddItem(context, ref),
              icon: const Icon(Icons.inventory_2),
              label: const Text('Add Item'),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_container',
            onPressed: () => _showAddContainerDialog(context, ref),
            icon: const Icon(Icons.add),
            label: Text(widget.breadcrumb.isEmpty ? 'Add Room' : 'Add Container'),
          ),
        ],
      ),
    );
  }

  String _getBreadcrumbText() {
    if (widget.breadcrumb.length == 1) {
      return widget.householdName;
    }
    return '${widget.householdName} → ${widget.breadcrumb.take(widget.breadcrumb.length - 1).map((c) => c.name).join(' → ')}';
  }

  Widget _buildUnorganizedItemsCard(BuildContext context, WidgetRef ref, List<Item> items) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.inventory_2, color: Colors.white),
        ),
        title: Text('Unorganized Items (${items.length})'),
        subtitle: const Text('Items not in any room yet'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () async {
          // Navigate to ItemListScreen with unorganized filter
          // Get household info from providers
          final householdsAsync = await ref.read(userHouseholdsProvider.future);
          final household = householdsAsync.firstWhere(
            (h) => h.id == widget.householdId,
            orElse: () => throw Exception('Household not found'),
          );

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemListScreen(
                  household: household,
                  initialFilter: 'unorganized',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildContainerCard(BuildContext context, WidgetRef ref, model.Container container) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildContainerThumbnail(ref, container),
        title: Text(container.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.Container.getTypeDisplayName(container.containerType)),
            if (container.description != null)
              Text(
                container.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEditMode) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditContainerDialog(context, ref, container),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(context, ref, container),
              ),
            ],
            const Icon(Icons.arrow_forward_ios),
          ],
        ),
        onTap: () {
          // Navigate into this container
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContainerScreen(
                householdId: widget.householdId,
                householdName: widget.householdName,
                parentContainerId: container.id,
                breadcrumb: [...widget.breadcrumb, container],
              ),
            ),
          );
        },
        onLongPress: () {
          _showEditContainerDialog(context, ref, container);
        },
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, WidgetRef ref, Item item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildItemThumbnail(ref, item),
        title: Text(item.title),
        subtitle: _buildItemSubtitle(item),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEditMode) ...[
              IconButton(
                icon: const Icon(Icons.drive_file_move),
                onPressed: () => _showMoveItemDialog(context, ref, item),
                tooltip: 'Move to another container',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteItemConfirmation(context, ref, item),
                tooltip: 'Delete item',
              ),
            ],
            const Icon(Icons.arrow_forward_ios),
          ],
        ),
        onTap: () async {
          // Create a minimal household object for navigation
          // (ItemDetailScreen needs it mainly for the ID and name)
          final household = Household(
            id: widget.householdId,
            name: widget.householdName,
            createdBy: '',
            members: {},
            createdAt: DateTime.now(),
            code: '',
          );

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemDetailScreen(
                  item: item,
                  household: household,
                ),
              ),
            );
          }
        },
        onLongPress: () {
          // Create a minimal household object for navigation
          final household = Household(
            id: widget.householdId,
            name: widget.householdName,
            createdBy: '',
            members: {},
            createdAt: DateTime.now(),
            code: '',
          );

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

  Widget _buildItemSubtitle(Item item) {
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
        return Text('${item.type} • Qty: ${item.quantity}');
    }
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
            onTap: () => ref.read(selectedTypeProvider.notifier).state = 'vinyl',
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

  void _showOtherTypesDialog(WidgetRef ref) {
    final otherTypes = ['general', 'pantry', 'camera', 'electronics', 'clothing', 'kitchen', 'outdoor'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Other Types'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: otherTypes.map((type) {
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

  Widget _buildContainerThumbnail(WidgetRef ref, model.Container container) {
    if (container.photoThumbPath == null) {
      return CircleAvatar(
        child: Icon(_getContainerIcon(container)),
      );
    }

    final containerRepo = ref.read(containerRepositoryProvider);

    return FutureBuilder<String?>(
      future: containerRepo.getPhotoUrl(container.photoThumbPath!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(snapshot.data!),
          );
        }
        return CircleAvatar(
          child: Icon(_getContainerIcon(container)),
        );
      },
    );
  }

  Widget _buildItemThumbnail(WidgetRef ref, Item item) {
    if (item.photoThumbPath == null) {
      return CircleAvatar(
        child: Icon(_getIconForItemType(item.type)),
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
          child: Icon(_getIconForItemType(item.type)),
        );
      },
    );
  }

  IconData _getIconForItemType(String type) {
    switch (type) {
      case 'book':
        return Icons.book;
      case 'vinyl':
        return Icons.album;
      case 'game':
        return Icons.sports_esports;
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

  IconData _getContainerIcon(model.Container container) {
    if (container.icon != null) {
      return _getIconFromName(container.icon!);
    }
    // Default icons based on type
    switch (container.containerType) {
      case 'room':
        return Icons.meeting_room;
      case 'shelf':
        return Icons.shelves;
      case 'box':
        return Icons.inventory_2;
      case 'fridge':
        return Icons.kitchen;
      case 'drawer':
        return Icons.kitchen_outlined;
      case 'cabinet':
        return Icons.door_sliding;
      case 'closet':
        return Icons.checkroom;
      case 'bin':
        return Icons.delete_outline;
      default:
        return Icons.inventory_2;
    }
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'kitchen':
        return Icons.kitchen;
      case 'bedroom':
        return Icons.bed;
      case 'living_room':
        return Icons.weekend;
      case 'bathroom':
        return Icons.bathroom;
      case 'garage':
        return Icons.garage;
      case 'office':
        return Icons.computer;
      case 'storage':
        return Icons.inventory_2;
      default:
        return Icons.inventory_2;
    }
  }

  void _showAddContainerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = widget.breadcrumb.isEmpty ? 'room' : 'shelf';
    String? selectedIcon;
    File? selectedPhoto;
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(widget.breadcrumb.isEmpty ? 'Add Room' : 'Add Container'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Kitchen, Top Shelf',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _getContainerTypes(widget.breadcrumb.isEmpty)
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(model.Container.getTypeDisplayName(type)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Brief description',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ImageSource? source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Take Photo'),
                              onTap: () => Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Choose from Gallery'),
                              onTap: () => Navigator.pop(context, ImageSource.gallery),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );

                    if (source != null) {
                      final XFile? image = await picker.pickImage(
                        source: source,
                        maxWidth: 1920,
                        maxHeight: 1080,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        setState(() {
                          selectedPhoto = File(image.path);
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(selectedPhoto == null ? 'Add Photo (Optional)' : 'Photo Selected'),
                ),
                if (selectedPhoto != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(selectedPhoto!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedPhoto = null;
                      });
                    },
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Remove Photo'),
                  ),
                ],
                if (widget.breadcrumb.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Select Room Icon:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _IconOption(
                        icon: Icons.kitchen,
                        label: 'Kitchen',
                        value: 'kitchen',
                        selected: selectedIcon == 'kitchen',
                        onTap: () => setState(() => selectedIcon = 'kitchen'),
                      ),
                      _IconOption(
                        icon: Icons.bed,
                        label: 'Bedroom',
                        value: 'bedroom',
                        selected: selectedIcon == 'bedroom',
                        onTap: () => setState(() => selectedIcon = 'bedroom'),
                      ),
                      _IconOption(
                        icon: Icons.weekend,
                        label: 'Living Room',
                        value: 'living_room',
                        selected: selectedIcon == 'living_room',
                        onTap: () => setState(() => selectedIcon = 'living_room'),
                      ),
                      _IconOption(
                        icon: Icons.bathroom,
                        label: 'Bathroom',
                        value: 'bathroom',
                        selected: selectedIcon == 'bathroom',
                        onTap: () => setState(() => selectedIcon = 'bathroom'),
                      ),
                      _IconOption(
                        icon: Icons.garage,
                        label: 'Garage',
                        value: 'garage',
                        selected: selectedIcon == 'garage',
                        onTap: () => setState(() => selectedIcon = 'garage'),
                      ),
                      _IconOption(
                        icon: Icons.computer,
                        label: 'Office',
                        value: 'office',
                        selected: selectedIcon == 'office',
                        onTap: () => setState(() => selectedIcon = 'office'),
                      ),
                      _IconOption(
                        icon: Icons.inventory_2,
                        label: 'Storage',
                        value: 'storage',
                        selected: selectedIcon == 'storage',
                        onTap: () => setState(() => selectedIcon = 'storage'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                try {
                  final containerService = ref.read(containerServiceProvider);
                  final containerRepo = ref.read(containerRepositoryProvider);
                  final authService = ref.read(authServiceProvider);

                  // Create container first to get the ID
                  final containerId = await containerService.createContainer(
                    householdId: widget.householdId,
                    name: nameController.text.trim(),
                    containerType: selectedType,
                    creatorUid: authService.currentUserId!,
                    parentId: widget.parentContainerId,
                    description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    icon: selectedIcon,
                  );

                  // Upload photo if selected
                  if (selectedPhoto != null) {
                    final photoPaths = await containerRepo.uploadPhoto(
                      householdId: widget.householdId,
                      containerId: containerId,
                      userId: authService.currentUserId!,
                      photo: selectedPhoto!,
                    );

                    // Update container with photo paths
                    await containerService.updateContainer(
                      containerId: containerId,
                      photoPath: photoPaths['photoPath'],
                      photoThumbPath: photoPaths['photoThumbPath'],
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${model.Container.getTypeDisplayName(selectedType)} created!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getContainerTypes(bool isTopLevel) {
    if (isTopLevel) {
      return ['room'];
    }
    return ['shelf', 'box', 'fridge', 'drawer', 'cabinet', 'closet', 'bin'];
  }

  void _showEditContainerDialog(BuildContext context, WidgetRef ref, model.Container container) {
    final nameController = TextEditingController(text: container.name);
    final descriptionController = TextEditingController(text: container.description);
    String selectedType = container.containerType;
    String? selectedIcon = container.icon;
    File? selectedPhoto;
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Container'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _getContainerTypes(container.isTopLevel)
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(model.Container.getTypeDisplayName(type)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ImageSource? source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Take Photo'),
                              onTap: () => Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Choose from Gallery'),
                              onTap: () => Navigator.pop(context, ImageSource.gallery),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );

                    if (source != null) {
                      final XFile? image = await picker.pickImage(
                        source: source,
                        maxWidth: 1920,
                        maxHeight: 1080,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        setState(() {
                          selectedPhoto = File(image.path);
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(
                    selectedPhoto == null
                      ? (container.photoPath == null ? 'Add Photo (Optional)' : 'Change Photo (Optional)')
                      : 'New Photo Selected'
                  ),
                ),
                if (selectedPhoto != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(selectedPhoto!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedPhoto = null;
                      });
                    },
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Remove New Photo'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                try {
                  final containerService = ref.read(containerServiceProvider);
                  final containerRepo = ref.read(containerRepositoryProvider);
                  final authService = ref.read(authServiceProvider);

                  // Upload photo if selected
                  String? photoPath;
                  String? photoThumbPath;
                  if (selectedPhoto != null) {
                    final photoPaths = await containerRepo.uploadPhoto(
                      householdId: widget.householdId,
                      containerId: container.id,
                      userId: authService.currentUserId!,
                      photo: selectedPhoto!,
                    );
                    photoPath = photoPaths['photoPath'];
                    photoThumbPath = photoPaths['photoThumbPath'];
                  }

                  await containerService.updateContainer(
                    containerId: container.id,
                    name: nameController.text.trim(),
                    containerType: selectedType,
                    description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    icon: selectedIcon,
                    photoPath: photoPath,
                    photoThumbPath: photoThumbPath,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Container updated!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, model.Container container) async {
    // Check for items and child containers
    final itemsAsync = await ref.read(containerItemsProvider(container.id).future);
    final childrenAsync = await ref.read(childContainersProvider(container.id).future);

    final items = itemsAsync;
    final children = childrenAsync;

    final itemCount = items.length;
    final childCount = children.length;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Container'),
        content: itemCount > 0 || childCount > 0
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cannot delete "${container.name}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (itemCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.inventory_2, size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Contains $itemCount ${itemCount == 1 ? 'item' : 'items'}'),
                      ],
                    ),
                  if (childCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.folder, size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Contains $childCount sub-${childCount == 1 ? 'container' : 'containers'}'),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please move or delete the contents first.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              )
            : Text('Are you sure you want to delete "${container.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(itemCount > 0 || childCount > 0 ? 'OK' : 'Cancel'),
          ),
          if (itemCount == 0 && childCount == 0)
            TextButton(
              onPressed: () async {
                try {
                  final containerService = ref.read(containerServiceProvider);
                  await containerService.deleteContainer(container.id);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Container deleted')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _showDeleteItemConfirmation(BuildContext context, WidgetRef ref, Item item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final itemRepo = ref.read(itemRepositoryProvider);
                await itemRepo.deleteItem(widget.householdId, item.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting item: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMoveItemDialog(BuildContext context, WidgetRef ref, Item item) async {
    final allContainers = await ref.read(allContainersProvider.future);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move "${item.title}"'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.inbox),
                title: const Text('Unorganized'),
                subtitle: const Text('Remove from container'),
                onTap: () async {
                  Navigator.pop(context);
                  await _moveItem(context, ref, item, null);
                },
              ),
              const Divider(),
              ...allContainers.map((container) {
                final isCurrent = item.containerId == container.id;
                return ListTile(
                  leading: Icon(
                    _getContainerIcon(container),
                    color: isCurrent ? Colors.blue : null,
                  ),
                  title: Text(
                    container.name,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : null,
                      color: isCurrent ? Colors.blue : null,
                    ),
                  ),
                  subtitle: Text(model.Container.getTypeDisplayName(container.containerType)),
                  trailing: isCurrent ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: isCurrent
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _moveItem(context, ref, item, container.id);
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

  Future<void> _moveItem(
    BuildContext context,
    WidgetRef ref,
    Item item,
    String? newContainerId,
  ) async {
    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      await itemRepo.moveItem(
        householdId: widget.householdId,
        itemId: item.id,
        newContainerId: newContainerId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newContainerId == null ? 'Item moved to unorganized' : 'Item moved successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving item: ${e.toString()}')),
        );
      }
    }
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
                      householdId: widget.householdId,
                      initialMode: BookScanMode.camera,
                      preSelectedContainerId: widget.parentContainerId,
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
                      householdId: widget.householdId,
                      initialMode: VinylScanMode.camera,
                      preSelectedContainerId: widget.parentContainerId,
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
                      householdId: widget.householdId,
                      preSelectedContainerId: widget.parentContainerId,
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

  void _navigateToAddItem(BuildContext context, WidgetRef ref) async {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItemTypeSelectionScreen(
            householdId: widget.householdId,
            preSelectedContainerId: widget.parentContainerId,
          ),
        ),
      );
    }
  }

}

class _IconOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _IconOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
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
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Theme.of(context).colorScheme.onPrimary : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
