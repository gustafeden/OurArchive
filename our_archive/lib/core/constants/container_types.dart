import 'package:flutter/material.dart';

/// Centralized container type definitions with icon mappings
/// Replaces duplicate icon mapping functions for containers
enum ContainerType {
  box('box', 'Box', Icons.inventory_2),
  shelf('shelf', 'Shelf', Icons.view_agenda),
  drawer('drawer', 'Drawer', Icons.layers),
  cabinet('cabinet', 'Cabinet', Icons.door_sliding),
  closet('closet', 'Closet', Icons.door_back_door),
  room('room', 'Room', Icons.meeting_room),
  storage('storage', 'Storage Unit', Icons.storage),
  garage('garage', 'Garage', Icons.garage),
  attic('attic', 'Attic', Icons.stairs),
  basement('basement', 'Basement', Icons.foundation),
  bin('bin', 'Bin', Icons.delete_outline),
  bag('bag', 'Bag', Icons.shopping_bag),
  storageCase('case', 'Case', Icons.work_outline),
  crate('crate', 'Crate', Icons.grid_view),
  folder('folder', 'Folder', Icons.folder),
  binder('binder', 'Binder', Icons.book),
  album('album', 'Album', Icons.photo_album),
  rack('rack', 'Rack', Icons.view_module),
  safe('safe', 'Safe', Icons.lock),
  trunk('trunk', 'Trunk', Icons.luggage),
  other('other', 'Other', Icons.category);

  const ContainerType(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  /// Get ContainerType from string value, defaults to 'other'
  static ContainerType fromString(String? value) {
    if (value == null) return ContainerType.other;
    return ContainerType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ContainerType.other,
    );
  }

  /// Get icon for a given container type string
  static IconData getIcon(String? type) {
    return fromString(type).icon;
  }

  /// Get all container types as dropdown items
  static List<DropdownMenuItem<String>> get dropdownItems {
    return ContainerType.values
        .map((type) => DropdownMenuItem(
              value: type.value,
              child: Row(
                children: [
                  Icon(type.icon, size: 20),
                  const SizedBox(width: 8),
                  Text(type.label),
                ],
              ),
            ))
        .toList();
  }
}
