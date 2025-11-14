import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/models/container.dart' as model;

class ContainerScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Get containers: top-level if parentContainerId is null, otherwise children
    final containersAsync = parentContainerId == null
        ? ref.watch(householdContainersProvider)
        : ref.watch(childContainersProvider(parentContainerId!));

    final title = breadcrumb.isEmpty
        ? householdName
        : breadcrumb.last.name;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (breadcrumb.isNotEmpty)
              Text(
                _getBreadcrumbText(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      body: containersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (containers) {
          if (containers.isEmpty) {
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
                    breadcrumb.isEmpty ? 'No rooms yet' : 'No containers yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    breadcrumb.isEmpty
                        ? 'Create your first room to get organized'
                        : 'Add shelves, boxes, or other containers',
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: containers.length,
            itemBuilder: (context, index) {
              final container = containers[index];
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
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showEditContainerDialog(context, ref, container),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _showDeleteConfirmation(context, ref, container),
                      ),
                      const Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                  onTap: () {
                    // Navigate into this container
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContainerScreen(
                          householdId: householdId,
                          householdName: householdName,
                          parentContainerId: container.id,
                          breadcrumb: [...breadcrumb, container],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContainerDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(breadcrumb.isEmpty ? 'Add Room' : 'Add Container'),
      ),
    );
  }

  String _getBreadcrumbText() {
    if (breadcrumb.length == 1) {
      return householdName;
    }
    return '$householdName → ${breadcrumb.take(breadcrumb.length - 1).map((c) => c.name).join(' → ')}';
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
    String selectedType = breadcrumb.isEmpty ? 'room' : 'shelf';
    String? selectedIcon;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(breadcrumb.isEmpty ? 'Add Room' : 'Add Container'),
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
                  items: _getContainerTypes(breadcrumb.isEmpty)
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
                if (breadcrumb.isEmpty) ...[
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
                    householdId: householdId,
                    name: nameController.text.trim(),
                    containerType: selectedType,
                    creatorUid: authService.currentUserId!,
                    parentId: parentContainerId,
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
      BuildContext context, WidgetRef ref, model.Container container) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Container'),
        content: Text('Are you sure you want to delete "${container.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
