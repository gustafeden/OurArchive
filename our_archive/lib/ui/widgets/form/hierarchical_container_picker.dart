import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../providers/providers.dart';
import '../../../data/models/container.dart' as models;
import '../../../utils/icon_helper.dart';

/// A hierarchical container picker that shows containers in a tree structure
/// with search functionality. Opens in a modal bottom sheet.
class HierarchicalContainerPicker extends ConsumerStatefulWidget {
  final String? selectedContainerId;
  final ValueChanged<String?> onChanged;
  final String? labelText;

  const HierarchicalContainerPicker({
    super.key,
    required this.selectedContainerId,
    required this.onChanged,
    this.labelText = 'Container (optional)',
  });

  @override
  ConsumerState<HierarchicalContainerPicker> createState() =>
      _HierarchicalContainerPickerState();
}

class _HierarchicalContainerPickerState
    extends ConsumerState<HierarchicalContainerPicker> {
  @override
  Widget build(BuildContext context) {
    final containersAsync = ref.watch(allContainersProvider);

    return containersAsync.when(
      data: (containers) {
        // Find selected container for display
        models.Container? selectedContainer;
        if (widget.selectedContainerId != null) {
          try {
            selectedContainer = containers.firstWhere(
              (c) => c.id == widget.selectedContainerId,
            );
          } catch (_) {
            // Container not found
          }
        }

        return InkWell(
          onTap: () => _showContainerPicker(context, containers),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.labelText,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Ionicons.cube_outline),
              suffixIcon: const Icon(Ionicons.chevron_down_outline),
            ),
            child: Text(
              selectedContainer != null
                  ? selectedContainer.name
                  : 'None (unorganized)',
              style: TextStyle(
                color: selectedContainer != null
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Failed to load containers'),
    );
  }

  void _showContainerPicker(BuildContext context, List<models.Container> containers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ContainerPickerSheet(
        containers: containers,
        selectedContainerId: widget.selectedContainerId,
        onSelected: (containerId) {
          widget.onChanged(containerId);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _ContainerPickerSheet extends StatefulWidget {
  final List<models.Container> containers;
  final String? selectedContainerId;
  final ValueChanged<String?> onSelected;

  const _ContainerPickerSheet({
    required this.containers,
    required this.selectedContainerId,
    required this.onSelected,
  });

  @override
  State<_ContainerPickerSheet> createState() => _ContainerPickerSheetState();
}

class _ContainerPickerSheetState extends State<_ContainerPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedNodes = {};

  @override
  void initState() {
    super.initState();
    // Auto-expand nodes leading to the selected container
    if (widget.selectedContainerId != null) {
      _expandPathToContainer(widget.selectedContainerId!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _expandPathToContainer(String containerId) {
    // Find the container and expand all its parents
    final container = widget.containers.where((c) => c.id == containerId).firstOrNull;
    if (container == null) return;

    String? currentParentId = container.parentId;
    while (currentParentId != null) {
      _expandedNodes.add(currentParentId);
      final parent = widget.containers.where((c) => c.id == currentParentId).firstOrNull;
      currentParentId = parent?.parentId;
    }
  }

  List<models.Container> _getFilteredContainers() {
    if (_searchQuery.isEmpty) {
      return widget.containers;
    }

    final query = _searchQuery.toLowerCase();
    final matching = widget.containers.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.containerType.toLowerCase().contains(query);
    }).toList();

    // When searching, expand all parent nodes of matching containers
    for (final container in matching) {
      String? currentParentId = container.parentId;
      while (currentParentId != null) {
        _expandedNodes.add(currentParentId);
        final parent = widget.containers.where((c) => c.id == currentParentId).firstOrNull;
        currentParentId = parent?.parentId;
      }
    }

    return matching;
  }

  List<models.Container> _getTopLevelContainers(List<models.Container> containers) {
    return containers.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<models.Container> _getChildren(String parentId, List<models.Container> containers) {
    return containers.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  bool _hasChildren(String containerId) {
    return widget.containers.any((c) => c.parentId == containerId);
  }

  @override
  Widget build(BuildContext context) {
    final filteredContainers = _getFilteredContainers();
    final topLevelContainers = _getTopLevelContainers(filteredContainers);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Select Container',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Ionicons.close_outline),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search containers...',
                  prefixIcon: const Icon(Ionicons.search_outline),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Ionicons.close_circle_outline),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            const Divider(height: 1),

            // Container list
            Expanded(
              child: widget.containers.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // "None" option
                        _buildContainerTile(
                          container: null,
                          depth: 0,
                          isSelected: widget.selectedContainerId == null,
                        ),
                        const Divider(height: 1),

                        // Tree view of containers
                        if (topLevelContainers.isEmpty && _searchQuery.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('No containers found'),
                            ),
                          )
                        else
                          ...topLevelContainers.map(
                            (container) => _buildContainerTree(
                              container,
                              filteredContainers,
                              0,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Ionicons.cube_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No containers yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create rooms and containers to organize your items.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerTree(
    models.Container container,
    List<models.Container> filteredContainers,
    int depth,
  ) {
    final hasChildren = _hasChildren(container.id);
    final isExpanded = _expandedNodes.contains(container.id);
    final children = _getChildren(container.id, filteredContainers);
    final isVisible = _searchQuery.isEmpty ||
        filteredContainers.any((c) => c.id == container.id);

    if (!isVisible) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContainerTile(
          container: container,
          depth: depth,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          isSelected: widget.selectedContainerId == container.id,
          onToggleExpand: hasChildren
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedNodes.remove(container.id);
                    } else {
                      _expandedNodes.add(container.id);
                    }
                  });
                }
              : null,
        ),

        // Render children if expanded or searching
        if ((isExpanded || _searchQuery.isNotEmpty) && children.isNotEmpty)
          ...children.map(
            (child) => _buildContainerTree(child, filteredContainers, depth + 1),
          ),
      ],
    );
  }

  Widget _buildContainerTile({
    required models.Container? container,
    required int depth,
    bool hasChildren = false,
    bool isExpanded = false,
    required bool isSelected,
    VoidCallback? onToggleExpand,
  }) {
    final indentWidth = depth * 24.0;

    return InkWell(
      onTap: () => widget.onSelected(container?.id),
      child: Container(
        color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
        padding: EdgeInsets.only(
          left: 16 + indentWidth,
          right: 16,
          top: 12,
          bottom: 12,
        ),
        child: Row(
          children: [
            // Expand/collapse chevron
            if (hasChildren)
              GestureDetector(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isExpanded
                        ? Ionicons.chevron_down_outline
                        : Ionicons.chevron_forward_outline,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              )
            else if (depth > 0)
              const SizedBox(width: 28), // Spacing for alignment

            // Container icon
            Icon(
              container != null
                  ? (container.icon != null
                      ? IconHelper.getIconData(container.icon!)
                      : IconHelper.getContainerIcon(container.containerType))
                  : Ionicons.file_tray_outline,
              size: 24,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[700],
            ),
            const SizedBox(width: 12),

            // Container info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    container?.name ?? 'None (unorganized)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                  if (container != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      models.Container.getTypeDisplayName(container.containerType),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Selected indicator
            if (isSelected)
              Icon(
                Ionicons.checkmark_circle,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
