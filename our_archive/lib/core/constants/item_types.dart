import 'package:flutter/material.dart';

/// Centralized item type definitions with icon mappings
/// Replaces 6+ duplicate icon mapping functions across the codebase
enum ItemType {
  book('book', 'Book', Icons.book),
  vinyl('vinyl', 'Vinyl', Icons.album),
  game('game', 'Game', Icons.sports_esports),
  tool('tool', 'Tool', Icons.build),
  pantry('pantry', 'Pantry', Icons.restaurant),
  camera('camera', 'Camera', Icons.camera_alt),
  electronics('electronics', 'Electronics', Icons.devices),
  clothing('clothing', 'Clothing', Icons.checkroom),
  kitchen('kitchen', 'Kitchen', Icons.kitchen),
  outdoor('outdoor', 'Outdoor', Icons.park),
  other('other', 'Other', Icons.inventory_2);

  const ItemType(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  /// Get ItemType from string value, defaults to 'other'
  static ItemType fromString(String? value) {
    if (value == null) return ItemType.other;
    return ItemType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ItemType.other,
    );
  }

  /// Get icon for a given item type string
  static IconData getIcon(String? type) {
    return fromString(type).icon;
  }

  /// Get all item types as dropdown items
  static List<DropdownMenuItem<String>> get dropdownItems {
    return ItemType.values
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
