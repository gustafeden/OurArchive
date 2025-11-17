import 'package:ionicons/ionicons.dart';
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
import 'item_list_screen.dart';
import 'book_scan_screen.dart';
import 'vinyl_scan_screen.dart';
import 'manage_types_screen.dart';
import 'common/scan_modes.dart';
import '../../utils/icon_helper.dart';
import '../../../data/models/container_type.dart';
import '../widgets/common/category_tabs_builder.dart';
import '../widgets/common/item_card_widget.dart';
import '../widgets/common/item_list_view.dart';

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
  bool _showItemsOnly = false;
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

    // Get items directly in this container
    final selectedType = ref.watch(selectedTypeProvider);
    final itemsAsync = ref.watch(containerItemsProvider(widget.parentContainerId));

    // Get all items recursively (for items-only view)
    final nestedItemsAsync = ref.watch(nestedContainerItemsProvider(widget.parentContainerId));
    final viewMode = ref.watch(viewModeProvider);

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
            icon: Icon(_isSearching ? Ionicons.close_outline : Ionicons.search_outline),
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
              } else if (value == 'view_mode') {
                setState(() {
                  _showItemsOnly = !_showItemsOnly;
                });
              } else if (value == 'toggle_list_browse') {
                ref.read(viewModeProvider.notifier).state =
                    viewMode == ViewMode.list ? ViewMode.browse : ViewMode.list;
              } else if (value == 'manage_types') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageTypesScreen(
                      householdId: widget.householdId,
                    ),
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
                      _showItemsOnly ? Ionicons.grid_outline : Ionicons.list_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_showItemsOnly ? 'Show Containers' : 'View All Items'),
                  ],
                ),
              ),
              if (_showItemsOnly)
                PopupMenuItem(
                  value: 'toggle_list_browse',
                  child: Row(
                    children: [
                      Icon(
                        viewMode == ViewMode.list ? Ionicons.albums_outline : Ionicons.reorder_four_outline,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(viewMode == ViewMode.list ? 'Browse Mode' : 'List Mode'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(_isEditMode ? Ionicons.checkmark_done_outline : Ionicons.create_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(_isEditMode ? 'Done Editing' : 'Edit Mode'),
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
            ],
          ),
        ],
      ),
      body: _showItemsOnly
          ? _buildItemsOnlyView(nestedItemsAsync)
          : containersAsync.when(
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
                        Ionicons.cube_outline,
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
                  if (items.isNotEmpty)
                    CategoryTabsBuilder.dynamic(
                      items: items,
                      householdId: widget.householdId,
                    ),

                  // Content list
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        // Unorganized items card at top level
                        if (widget.breadcrumb.isEmpty && filteredItems.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildUnorganizedItemsCard(context, ref, filteredItems),
                          ),

                        // Containers in a grid
                        if (filteredContainers.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final container = filteredContainers[index];
                                  return _buildContainerCard(context, ref, container);
                                },
                                childCount: filteredContainers.length,
                              ),
                            ),
                          ),

                        // Items list at the end
                        if (filteredItems.isNotEmpty && widget.breadcrumb.isNotEmpty)
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final household = Household(
                                  id: widget.householdId,
                                  name: widget.householdName,
                                  createdBy: '',
                                  members: {},
                                  createdAt: DateTime.now(),
                                  code: '',
                                );
                                return ItemCardWidget(
                                  item: filteredItems[index],
                                  household: household,
                                  showEditActions: _isEditMode,
                                  onMoveItem: () => _showMoveItemDialog(context, ref, filteredItems[index]),
                                  onDeleteItem: () => _showDeleteItemConfirmation(context, ref, filteredItems[index]),
                                );
                              },
                              childCount: filteredItems.length,
                            ),
                          ),
                      ],
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
              icon: const Icon(Ionicons.cube_outline),
              label: const Text('Add Item'),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_container',
            onPressed: () => _showAddContainerDialog(context, ref),
            icon: const Icon(Ionicons.add_outline),
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

  Widget _buildItemsOnlyView(AsyncValue<List<Item>> nestedItemsAsync) {
    return nestedItemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (allItems) {
        // Apply search filter
        var filteredItems = allItems;
        if (_searchQuery.isNotEmpty) {
          filteredItems = allItems.where((item) {
            return item.title.toLowerCase().contains(_searchQuery) ||
                (item.authors?.any((author) => author.toLowerCase().contains(_searchQuery)) ?? false) ||
                (item.artist?.toLowerCase().contains(_searchQuery) ?? false) ||
                (item.platform?.toLowerCase().contains(_searchQuery) ?? false) ||
                item.type.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Ionicons.cube_outline,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty ? 'No items found' : 'No items yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Try a different search term'
                      : 'Add items to this container',
                ),
              ],
            ),
          );
        }

        final household = Household(
          id: widget.householdId,
          name: widget.householdName,
          createdBy: '',
          members: {},
          createdAt: DateTime.now(),
          code: '',
        );

        final viewMode = ref.watch(viewModeProvider);

        return Column(
          children: [
            // Category tabs
            CategoryTabsBuilder.dynamic(
              items: allItems,
              householdId: widget.householdId,
            ),

            // Items list view
            Expanded(
              child: ItemListView(
                items: filteredItems,
                household: household,
                viewMode: viewMode,
                showSyncStatus: false,
                showLocationInSubtitle: true,
                showEditActions: _isEditMode,
                onMoveItem: (item) => _showMoveItemDialog(context, ref, item),
                onDeleteItem: (item) => _showDeleteItemConfirmation(context, ref, item),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnorganizedItemsCard(BuildContext context, WidgetRef ref, List<Item> items) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Ionicons.cube_outline, color: Colors.white),
        ),
        title: Text('Unorganized Items (${items.length})'),
        subtitle: const Text('Items not in any room yet'),
        trailing: const Icon(Ionicons.chevron_forward_outline),
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
                settings: const RouteSettings(name: '/item_list'),
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
    final containerRepo = ref.read(containerRepositoryProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Navigate into this container
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/container'),
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
        child: Container(
          height: 150,
          decoration: container.photoThumbPath != null
              ? null
              : BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                  ),
                ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image if available
              if (container.photoThumbPath != null)
                FutureBuilder<String?>(
                  future: containerRepo.getPhotoUrl(container.photoThumbPath!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return CachedNetworkImage(
                        imageUrl: snapshot.data!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primaryContainer,
                                Theme.of(context).colorScheme.secondaryContainer,
                              ],
                            ),
                          ),
                          child: Icon(
                            _getContainerIcon(container),
                            size: 48,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.secondaryContainer,
                          ],
                        ),
                      ),
                      child: Icon(
                        _getContainerIcon(container),
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    );
                  },
                ),

              // Icon for containers without photos
              if (container.photoThumbPath == null)
                Center(
                  child: Icon(
                    _getContainerIcon(container),
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),

              // Gradient overlay for text readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        container.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model.Container.getTypeDisplayName(container.containerType),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                      if (container.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          container.description!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Edit buttons in edit mode
              if (_isEditMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Ionicons.create_outline, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                        onPressed: () => _showEditContainerDialog(context, ref, container),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Ionicons.trash_outline, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.7),
                        ),
                        onPressed: () => _showDeleteConfirmation(context, ref, container),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getContainerIcon(model.Container container) {
    // Try to get icon from container's icon field first
    if (container.icon != null) {
      return IconHelper.getIconData(container.icon!);
    }
    // Fallback to type-based icon
    return IconHelper.getContainerIcon(container.containerType);
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'kitchen':
        return Ionicons.restaurant_outline;
      case 'bedroom':
        return Ionicons.bed_outline;
      case 'living_room':
        return Ionicons.tv_outline;
      case 'bathroom':
        return Ionicons.water_outline;
      case 'garage':
        return Ionicons.car_outline;
      case 'office':
        return Ionicons.desktop_outline;
      case 'storage':
        return Ionicons.cube_outline;
      default:
        return Ionicons.cube_outline;
    }
  }

  /// Shows a modal bottom sheet to select image source (camera or gallery)
  /// Returns the selected ImageSource or null if cancelled
  Future<ImageSource?> _showImageSourcePicker(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Ionicons.camera_outline),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Ionicons.images_outline),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddContainerDialog(BuildContext context, WidgetRef ref) async {
    // Load container types first to avoid stuck loading state in dialog
    final containerTypes = await ref.read(containerTypesProvider(widget.householdId).future);

    if (!context.mounted) return;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    String selectedType = widget.breadcrumb.isEmpty ? 'room' : 'shelf';
    String? selectedIcon;
    File? selectedPhoto;
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Show all container types
          final availableTypes = containerTypes;

          // Ensure selectedType exists in available types
          if (!availableTypes.any((t) => t.name == selectedType)) {
            selectedType = availableTypes.isNotEmpty ? availableTypes.first.name : 'room';
          }

          return AlertDialog(
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
                      items: availableTypes
                          .map((type) => DropdownMenuItem(
                                value: type.name,
                                child: Row(
                                  children: [
                                    Icon(IconHelper.getIconData(type.icon), size: 20),
                                    const SizedBox(width: 8),
                                    Text(type.displayName),
                                  ],
                                ),
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
                        final ImageSource? source = await _showImageSourcePicker(context);

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
                      icon: const Icon(Ionicons.camera_outline),
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
                        icon: const Icon(Ionicons.trash_outline, size: 18),
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
                            icon: Ionicons.restaurant_outline,
                            label: 'Kitchen',
                            value: 'kitchen',
                            selected: selectedIcon == 'kitchen',
                            onTap: () => setState(() => selectedIcon = 'kitchen'),
                          ),
                          _IconOption(
                            icon: Ionicons.bed_outline,
                            label: 'Bedroom',
                            value: 'bedroom',
                            selected: selectedIcon == 'bedroom',
                            onTap: () => setState(() => selectedIcon = 'bedroom'),
                          ),
                          _IconOption(
                            icon: Ionicons.tv_outline,
                            label: 'Living Room',
                            value: 'living_room',
                            selected: selectedIcon == 'living_room',
                            onTap: () => setState(() => selectedIcon = 'living_room'),
                          ),
                          _IconOption(
                            icon: Ionicons.water_outline,
                            label: 'Bathroom',
                            value: 'bathroom',
                            selected: selectedIcon == 'bathroom',
                            onTap: () => setState(() => selectedIcon = 'bathroom'),
                          ),
                          _IconOption(
                            icon: Ionicons.car_outline,
                            label: 'Garage',
                            value: 'garage',
                            selected: selectedIcon == 'garage',
                            onTap: () => setState(() => selectedIcon = 'garage'),
                          ),
                          _IconOption(
                            icon: Ionicons.desktop_outline,
                            label: 'Office',
                            value: 'office',
                            selected: selectedIcon == 'office',
                            onTap: () => setState(() => selectedIcon = 'office'),
                          ),
                          _IconOption(
                            icon: Ionicons.cube_outline,
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

                    // Get icon from containerType if not manually selected
                    final iconToUse = selectedIcon ?? containerTypes.firstWhere((t) => t.name == selectedType).icon;

                    // Create container first to get the ID
                    final containerId = await containerService.createContainer(
                      householdId: widget.householdId,
                      name: nameController.text.trim(),
                      containerType: selectedType,
                      creatorUid: authService.currentUserId!,
                      parentId: widget.parentContainerId,
                      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      icon: iconToUse,
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
                      final typeDisplayName = containerTypes
                          .firstWhere((t) => t.name == selectedType,
                              orElse: () => ContainerType(
                                id: '',
                                name: selectedType,
                                displayName: selectedType.substring(0, 1).toUpperCase() + selectedType.substring(1),
                                icon: 'inventory_2',
                                isDefault: false,
                                allowNested: true,
                                createdAt: DateTime.now(),
                                createdBy: '',
                              ))
                          .displayName;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$typeDisplayName created!'),
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
          );
        },
      ),
    );
  }

  Future<void> _showEditContainerDialog(BuildContext context, WidgetRef ref, model.Container container) async {
    // Load container types first to avoid stuck loading state in dialog
    final containerTypes = await ref.read(containerTypesProvider(widget.householdId).future);

    if (!context.mounted) return;

    final nameController = TextEditingController(text: container.name);
    final descriptionController = TextEditingController(text: container.description);

    String selectedType = container.containerType;
    String? selectedIcon = container.icon;
    File? selectedPhoto;
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Show all container types
          final availableTypes = containerTypes;

          // Ensure selectedType exists in available types
          if (!availableTypes.any((t) => t.name == selectedType)) {
            selectedType = availableTypes.isNotEmpty ? availableTypes.first.name : 'room';
          }

          return AlertDialog(
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
                      items: availableTypes
                          .map((type) => DropdownMenuItem(
                                value: type.name,
                                child: Row(
                                  children: [
                                    Icon(IconHelper.getIconData(type.icon), size: 20),
                                    const SizedBox(width: 8),
                                    Text(type.displayName),
                                  ],
                                ),
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
                        final ImageSource? source = await _showImageSourcePicker(context);

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
                      icon: const Icon(Ionicons.camera_outline),
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
                        icon: const Icon(Ionicons.trash_outline, size: 18),
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

                    // Get icon from containerType if not manually selected
                    final iconToUse = selectedIcon ?? containerTypes.firstWhere((t) => t.name == selectedType).icon;

                    await containerService.updateContainer(
                      containerId: container.id,
                      name: nameController.text.trim(),
                      containerType: selectedType,
                      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      icon: iconToUse,
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
          );
        },
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
                        const Icon(Ionicons.cube_outline, size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Contains $itemCount ${itemCount == 1 ? 'item' : 'items'}'),
                      ],
                    ),
                  if (childCount > 0)
                    Row(
                      children: [
                        const Icon(Ionicons.folder_outline, size: 20, color: Colors.orange),
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
                  await containerService.deleteContainer(container.id, widget.householdId);

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
                leading: const Icon(Ionicons.mail_outline),
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
                  trailing: isCurrent ? const Icon(Ionicons.checkmark_outline, color: Colors.blue) : null,
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
                child: const Icon(Ionicons.qr_code_outline, color: Colors.blue),
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
                      initialMode: ScanMode.camera,
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
                child: const Icon(Ionicons.disc_outline, color: Colors.purple),
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
                      initialMode: ScanMode.camera,
                      preSelectedContainerId: widget.parentContainerId,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Ionicons.add_circle_outline),
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

