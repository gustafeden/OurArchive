import 'package:cloud_firestore/cloud_firestore.dart';

/// Flexible container that can represent any organizational unit:
/// Room, Shelf, Box, Fridge, Drawer, Cabinet, etc.
class Container {
  final String id;
  final String name;
  final String householdId;
  final String? parentId; // null for top-level containers (rooms)
  final String containerType; // 'room', 'shelf', 'box', 'fridge', 'drawer', 'cabinet', etc.
  final String? description;
  final String? icon; // Icon name for UI
  final DateTime createdAt;
  final DateTime lastModified;
  final String createdBy;
  final int sortOrder;

  Container({
    required this.id,
    required this.name,
    required this.householdId,
    this.parentId,
    required this.containerType,
    this.description,
    this.icon,
    required this.createdAt,
    required this.lastModified,
    required this.createdBy,
    this.sortOrder = 0,
  });

  factory Container.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      id: doc.id,
      name: data['name'] ?? '',
      householdId: data['householdId'] ?? '',
      parentId: data['parentId'],
      containerType: data['containerType'] ?? 'room',
      description: data['description'],
      icon: data['icon'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastModified: (data['lastModified'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'householdId': householdId,
        'parentId': parentId,
        'containerType': containerType,
        'description': description,
        'icon': icon,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastModified': Timestamp.fromDate(lastModified),
        'createdBy': createdBy,
        'sortOrder': sortOrder,
      };

  Container copyWith({
    String? name,
    String? parentId,
    String? containerType,
    String? description,
    String? icon,
    DateTime? lastModified,
    int? sortOrder,
  }) {
    return Container(
      id: id,
      name: name ?? this.name,
      householdId: householdId,
      parentId: parentId ?? this.parentId,
      containerType: containerType ?? this.containerType,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      createdAt: createdAt,
      lastModified: lastModified ?? this.lastModified,
      createdBy: createdBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // Helper to check if this is a top-level container (room)
  bool get isTopLevel => parentId == null;

  // Get display info based on container type
  static String getTypeDisplayName(String type) {
    switch (type) {
      case 'room':
        return 'Room';
      case 'shelf':
        return 'Shelf';
      case 'box':
        return 'Box';
      case 'fridge':
        return 'Fridge';
      case 'drawer':
        return 'Drawer';
      case 'cabinet':
        return 'Cabinet';
      case 'closet':
        return 'Closet';
      case 'bin':
        return 'Bin';
      default:
        return type;
    }
  }
}
