import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/models/container_type.dart';
import '../../data/models/item_type.dart';
import '../widgets/type_edit_dialog.dart';
import '../../utils/icon_helper.dart';

class ManageTypesScreen extends ConsumerStatefulWidget {
  final String householdId;

  const ManageTypesScreen({super.key, required this.householdId});

  @override
  ConsumerState<ManageTypesScreen> createState() => _ManageTypesScreenState();
}

class _ManageTypesScreenState extends ConsumerState<ManageTypesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasCheckedForDefaultTypes = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _ensureDefaultTypesExist() async {
    if (_hasCheckedForDefaultTypes) return;
    _hasCheckedForDefaultTypes = true;

    final typeService = ref.read(typeServiceProvider);
    final authService = ref.read(authServiceProvider);

    try {
      await typeService.seedDefaultTypes(
        householdId: widget.householdId,
        creatorUid: authService.currentUserId!,
      );
    } catch (e) {
      // Ignore errors - types might already exist
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  Future<void> _addContainerType() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const TypeEditDialog.container(isEdit: false),
    );

    if (result != null && mounted) {
      try {
        final typeService = ref.read(typeServiceProvider);
        final authService = ref.read(authServiceProvider);

        await typeService.addContainerType(
          householdId: widget.householdId,
          name: result['displayName'].toString().toLowerCase().replaceAll(' ', '_'),
          displayName: result['displayName'],
          icon: result['icon'],
          creatorUid: authService.currentUserId!,
          allowNested: result['allowNested'] ?? true,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Container type created!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _editContainerType(ContainerType type) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TypeEditDialog.container(
        isEdit: true,
        containerType: type,
      ),
    );

    if (result != null && mounted) {
      try {
        final typeService = ref.read(typeServiceProvider);

        await typeService.updateContainerType(
          householdId: widget.householdId,
          typeId: type.id,
          displayName: result['displayName'],
          icon: result['icon'],
          allowNested: result['allowNested'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Container type updated!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deleteContainerType(ContainerType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Container Type'),
        content: Text('Are you sure you want to delete "${type.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final typeService = ref.read(typeServiceProvider);
        await typeService.deleteContainerType(
          householdId: widget.householdId,
          typeId: type.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Container type deleted!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  Future<void> _addItemType() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const TypeEditDialog.item(isEdit: false),
    );

    if (result != null && mounted) {
      try {
        final typeService = ref.read(typeServiceProvider);
        final authService = ref.read(authServiceProvider);

        await typeService.addItemType(
          householdId: widget.householdId,
          name: result['displayName'].toString().toLowerCase().replaceAll(' ', '_'),
          displayName: result['displayName'],
          icon: result['icon'],
          creatorUid: authService.currentUserId!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item type created!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _editItemType(ItemType type) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TypeEditDialog.item(
        isEdit: true,
        itemType: type,
      ),
    );

    if (result != null && mounted) {
      try {
        final typeService = ref.read(typeServiceProvider);

        await typeService.updateItemType(
          householdId: widget.householdId,
          typeId: type.id,
          displayName: result['displayName'],
          icon: result['icon'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item type updated!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deleteItemType(ItemType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item Type'),
        content: Text('Are you sure you want to delete "${type.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final typeService = ref.read(typeServiceProvider);
        await typeService.deleteItemType(
          householdId: widget.householdId,
          typeId: type.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item type deleted!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Types'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Container Types'),
            Tab(text: 'Item Types'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContainerTypesTab(),
          _buildItemTypesTab(),
        ],
      ),
    );
  }

  Widget _buildContainerTypesTab() {
    final containerTypesAsync = ref.watch(containerTypesProvider(widget.householdId));

    return containerTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (types) {
        // Auto-seed default types if none exist
        if (types.isEmpty) {
          _ensureDefaultTypesExist();
        }

        final defaultTypes = types.where((t) => t.isDefault).toList();
        final customTypes = types.where((t) => !t.isDefault).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Custom types section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CUSTOM TYPES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addContainerType,
                  icon: const Icon(Ionicons.add_outline, size: 18),
                  label: const Text('Add Type'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (customTypes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No custom types yet.\nTap "Add Type" to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...customTypes.map((type) => _buildContainerTypeCard(type, false)),

            // Default types section
            if (defaultTypes.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'DEFAULT TYPES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ...defaultTypes.map((type) => _buildContainerTypeCard(type, true)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildContainerTypeCard(ContainerType type, bool isDefault) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(IconHelper.getIconData(type.icon)),
        ),
        title: Text(type.displayName),
        subtitle: Text(
          isDefault ? 'Built-in type' : 'Custom type',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isDefault
            ? const Chip(
                label: Text('Default', style: TextStyle(fontSize: 10)),
                padding: EdgeInsets.symmetric(horizontal: 8),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Ionicons.create_outline, size: 20),
                    onPressed: () => _editContainerType(type),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Ionicons.trash_outline, size: 20, color: Colors.red),
                    onPressed: () => _deleteContainerType(type),
                    tooltip: 'Delete',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildItemTypesTab() {
    final itemTypesAsync = ref.watch(itemTypesProvider(widget.householdId));

    return itemTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (types) {
        // Auto-seed default types if none exist
        if (types.isEmpty) {
          _ensureDefaultTypesExist();
        }

        final defaultTypes = types.where((t) => t.isDefault).toList();
        final customTypes = types.where((t) => !t.isDefault).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Custom types section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CUSTOM TYPES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addItemType,
                  icon: const Icon(Ionicons.add_outline, size: 18),
                  label: const Text('Add Type'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (customTypes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No custom types yet.\nTap "Add Type" to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...customTypes.map((type) => _buildItemTypeCard(type, false)),

            // Default types section
            if (defaultTypes.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'DEFAULT TYPES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ...defaultTypes.map((type) => _buildItemTypeCard(type, true)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildItemTypeCard(ItemType type, bool isDefault) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(IconHelper.getIconData(type.icon)),
        ),
        title: Text(type.displayName),
        subtitle: Text(
          isDefault
              ? type.hasSpecializedForm
                  ? 'Built-in type (specialized)'
                  : 'Built-in type'
              : 'Custom type',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isDefault
            ? const Chip(
                label: Text('Default', style: TextStyle(fontSize: 10)),
                padding: EdgeInsets.symmetric(horizontal: 8),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Ionicons.create_outline, size: 20),
                    onPressed: () => _editItemType(type),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Ionicons.trash_outline, size: 20, color: Colors.red),
                    onPressed: () => _deleteItemType(type),
                    tooltip: 'Delete',
                  ),
                ],
              ),
      ),
    );
  }
}
