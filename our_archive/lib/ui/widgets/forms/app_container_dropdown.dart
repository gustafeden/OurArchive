import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/container.dart' as models;
import '../../../providers/providers.dart';
import '../../../core/constants/container_types.dart';
import '../shared/app_async_value.dart';

/// Reusable container dropdown with hierarchical display
/// Eliminates duplicate container selection code across add-item screens
class AppContainerDropdown extends ConsumerWidget {
  const AppContainerDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Container (optional)',
  });

  final String? value;
  final Function(String?) onChanged;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final containersAsync = ref.watch(allContainersProvider);

    return AppAsyncValueSlim(
      value: containersAsync,
      data: (containers) {
        return DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.place),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('No container'),
            ),
            ...containers.map((container) {
              return DropdownMenuItem(
                value: container.id,
                child: Row(
                  children: [
                    Icon(
                      ContainerType.getIcon(container.containerType),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _buildHierarchicalName(container, containers),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: onChanged,
        );
      },
      errorMessage: 'Failed to load containers',
    );
  }

  /// Build hierarchical name (e.g., "Living Room > Shelf > Box")
  String _buildHierarchicalName(
    models.Container container,
    List<models.Container> allContainers,
  ) {
    if (container.parentId == null) {
      return container.name;
    }

    final parent = allContainers.firstWhere(
      (c) => c.id == container.parentId,
      orElse: () => container,
    );

    if (parent.id == container.id) {
      return container.name;
    }

    return '${_buildHierarchicalName(parent, allContainers)} > ${container.name}';
  }
}
