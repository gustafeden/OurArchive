import 'package:cloud_firestore/cloud_firestore.dart';

class ContainerType {
  final String id;
  final String name; // Internal ID (e.g., "room", "custom_wine_rack")
  final String displayName; // User-visible name (e.g., "Wine Rack")
  final String icon; // Material icon name
  final bool isDefault; // true for built-in types
  final bool allowNested; // true if can contain other containers
  final DateTime createdAt;
  final String createdBy;

  ContainerType({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    this.isDefault = false,
    this.allowNested = true,
    required this.createdAt,
    required this.createdBy,
  });

  factory ContainerType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContainerType(
      id: doc.id,
      name: data['name'] ?? '',
      displayName: data['displayName'] ?? '',
      icon: data['icon'] ?? 'inventory_2',
      isDefault: data['isDefault'] ?? false,
      allowNested: data['allowNested'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'displayName': displayName,
        'icon': icon,
        'isDefault': isDefault,
        'allowNested': allowNested,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
      };

  ContainerType copyWith({
    String? name,
    String? displayName,
    String? icon,
    bool? isDefault,
    bool? allowNested,
  }) {
    return ContainerType(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      icon: icon ?? this.icon,
      isDefault: isDefault ?? this.isDefault,
      allowNested: allowNested ?? this.allowNested,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  // Default container types
  static List<Map<String, dynamic>> get defaultTypes => [
        {
          'name': 'room',
          'displayName': 'Room',
          'icon': 'meeting_room',
          'isDefault': true,
          'allowNested': true,
        },
        {
          'name': 'shelf',
          'displayName': 'Shelf',
          'icon': 'shelves',
          'isDefault': true,
          'allowNested': true,
        },
        {
          'name': 'box',
          'displayName': 'Box',
          'icon': 'inventory_2',
          'isDefault': true,
          'allowNested': false,
        },
        {
          'name': 'fridge',
          'displayName': 'Fridge',
          'icon': 'kitchen',
          'isDefault': true,
          'allowNested': true,
        },
        {
          'name': 'drawer',
          'displayName': 'Drawer',
          'icon': 'category',
          'isDefault': true,
          'allowNested': false,
        },
        {
          'name': 'cabinet',
          'displayName': 'Cabinet',
          'icon': 'countertops',
          'isDefault': true,
          'allowNested': true,
        },
        {
          'name': 'closet',
          'displayName': 'Closet',
          'icon': 'door_sliding',
          'isDefault': true,
          'allowNested': true,
        },
        {
          'name': 'bin',
          'displayName': 'Bin',
          'icon': 'delete_outline',
          'isDefault': true,
          'allowNested': false,
        },
      ];
}
