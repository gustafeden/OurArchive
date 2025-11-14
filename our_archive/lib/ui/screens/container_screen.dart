import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/providers.dart';
import '../../data/models/container.dart' as model;
import '../../data/models/item.dart';
import '../../data/models/household.dart';
import 'add_item_screen.dart';
import 'barcode_scan_screen.dart';
import 'item_detail_screen.dart';
import 'item_list_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    // Get containers: top-level if parentContainerId is null, otherwise children
    final containersAsync = widget.parentContainerId == null
        ? ref.watch(householdContainersProvider)
        : ref.watch(childContainersProvider(widget.parentContainerId!));

    // Get items in this container (null = items without container)
    final itemsAsync = ref.watch(containerItemsProvider(widget.parentContainerId));

    final title = widget.breadcrumb.isEmpty
        ? widget.householdName
        : widget.breadcrumb.last.name;

    return Scaffold(
      appBar: AppBar(
        title: Column(
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
          TextButton(
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
            },
            child: Text(
              _isEditMode ? 'Done' : 'Edit',
              style: const TextStyle(fontSize: 16),
            ),
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

              return ListView.builder(
                itemCount: containers.length + (items.isNotEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show items section first if we have unorganized items at top level
                  if (widget.breadcrumb.isEmpty && items.isNotEmpty && index == 0) {
                    return _buildUnorganizedItemsCard(context, ref, items);
                  }

                  // Adjust index if we showed items card first
                  final containerIndex = (widget.breadcrumb.isEmpty && items.isNotEmpty)
                      ? index - 1
                      : index;

                  // Show items at the end for non-top-level
                  if (containerIndex >= containers.length) {
                    return Column(
                      children: items.map((item) => _buildItemCard(context, ref, item)).toList(),
                    );
                  }

                  final container = containers[containerIndex];
                  return _buildContainerCard(context, ref, container);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan_book',
            onPressed: () => _navigateToScanBook(context, ref),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Book'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_item',
            onPressed: () => _navigateToAddItem(context, ref),
            icon: const Icon(Icons.inventory_2),
            label: const Text('Add Item'),
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
    return '$widget.householdName → ${widget.breadcrumb.take(widget.breadcrumb.length - 1).map((c) => c.name).join(' → ')}';
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
        leading: CircleAvatar(
          child: Icon(_getContainerIcon(container)),
        ),
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
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, WidgetRef ref, Item item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildItemThumbnail(ref, item),
        title: Text(item.title),
        subtitle: Text('${item.type} • Qty: ${item.quantity}'),
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
      ),
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
                  final authService = ref.read(authServiceProvider);

                  await containerService.createContainer(
                    householdId: widget.householdId,
                    name: nameController.text.trim(),
                    containerType: selectedType,
                    creatorUid: authService.currentUserId!,
                    parentId: widget.parentContainerId,
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    icon: selectedIcon,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${model.Container.getTypeDisplayName(selectedType)} created!'),
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

  void _showEditContainerDialog(
      BuildContext context, WidgetRef ref, model.Container container) {
    final nameController = TextEditingController(text: container.name);
    final descriptionController =
        TextEditingController(text: container.description);
    String selectedType = container.containerType;
    String? selectedIcon = container.icon;

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

                  await containerService.updateContainer(
                    containerId: container.id,
                    name: nameController.text.trim(),
                    containerType: selectedType,
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    icon: selectedIcon,
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

  void _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, model.Container container) async {
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
              newContainerId == null
                  ? 'Item moved to unorganized'
                  : 'Item moved successfully',
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

  void _navigateToAddItem(BuildContext context, WidgetRef ref) async {
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
          builder: (context) => AddItemScreen(
            household: household,
            preSelectedContainerId: widget.parentContainerId,
          ),
        ),
      );
    }
  }

  void _navigateToScanBook(BuildContext context, WidgetRef ref) async {
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
          builder: (context) => BarcodeScanScreen(
            household: household,
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
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
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
