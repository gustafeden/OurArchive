import 'package:cloud_firestore/cloud_firestore.dart';

class ItemType {
  final String id;
  final String name; // Internal ID (e.g., "book", "custom_collectible")
  final String displayName; // User-visible name (e.g., "Collectible")
  final String icon; // Material icon name
  final int? color; // Color value for UI theming (optional)
  final bool isDefault; // true for built-in types
  final bool hasSpecializedForm; // true for book, vinyl, game (uses specialized screens)
  final DateTime createdAt;
  final String createdBy;

  ItemType({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    this.color,
    this.isDefault = false,
    this.hasSpecializedForm = false,
    required this.createdAt,
    required this.createdBy,
  });

  factory ItemType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemType(
      id: doc.id,
      name: data['name'] ?? '',
      displayName: data['displayName'] ?? '',
      icon: data['icon'] ?? 'inventory_2',
      color: data['color'],
      isDefault: data['isDefault'] ?? false,
      hasSpecializedForm: data['hasSpecializedForm'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'displayName': displayName,
        'icon': icon,
        'color': color,
        'isDefault': isDefault,
        'hasSpecializedForm': hasSpecializedForm,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
      };

  ItemType copyWith({
    String? name,
    String? displayName,
    String? icon,
    int? color,
    bool? isDefault,
    bool? hasSpecializedForm,
  }) {
    return ItemType(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      hasSpecializedForm: hasSpecializedForm ?? this.hasSpecializedForm,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  // Default item types
  static List<Map<String, dynamic>> get defaultTypes => [
        {
          'name': 'book',
          'displayName': 'Book',
          'icon': 'menu_book',
          'isDefault': true,
          'hasSpecializedForm': true,
        },
        {
          'name': 'vinyl',
          'displayName': 'Music',
          'icon': 'album',
          'isDefault': true,
          'hasSpecializedForm': true,
        },
        {
          'name': 'game',
          'displayName': 'Game',
          'icon': 'sports_esports',
          'isDefault': true,
          'hasSpecializedForm': true,
        },
        {
          'name': 'general',
          'displayName': 'General Item',
          'icon': 'inventory_2',
          'isDefault': true,
          'hasSpecializedForm': false,
        },
        {
          'name': 'tool',
          'displayName': 'Tool',
          'icon': 'build',
          'isDefault': true,
          'hasSpecializedForm': false,
        },
        {
          'name': 'pantry',
          'displayName': 'Pantry Item',
          'icon': 'kitchen',
          'isDefault': true,
          'hasSpecializedForm': false,
        },
        {
          'name': 'camera',
          'displayName': 'Camera Equipment',
          'icon': 'camera_alt',
          'isDefault': true,
          'hasSpecializedForm': false,
        },
        {
          'name': 'electronics',
          'displayName': 'Electronics',
          'icon': 'devices',
          'isDefault': true,
          'hasSpecializedForm': false,
        },
        {
          'name': 'clothing',
          'displayName': 'Clothing',
          'icon': 'checkroom',
          'isDefault': true,
          'hasSpecializedForm': false,
        },
        {
          'name': 'kitchen',
          'displayName': 'Kitchen',
          'icon': 'restaurant',
          'isDefault': true,
          'hasSpecializedForm': false,
        },
        {
          'name': 'outdoor',
          'displayName': 'Outdoor',
          'icon': 'park',
          'isDefault': true,
          'hasSpecializedForm': false,
        },
      ];
}
