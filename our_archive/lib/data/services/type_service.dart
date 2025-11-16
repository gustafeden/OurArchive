import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/container_type.dart';
import '../models/item_type.dart';

class TypeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ Container Types ============

  /// Get all container types for a household
  Stream<List<ContainerType>> getContainerTypes(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('containerTypes')
        .orderBy('isDefault', descending: true)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContainerType.fromFirestore(doc))
            .toList());
  }

  /// Add a new custom container type
  Future<String> addContainerType({
    required String householdId,
    required String name,
    required String displayName,
    required String icon,
    required String creatorUid,
    bool allowNested = true,
  }) async {
    final now = DateTime.now();

    // Validate uniqueness
    final existing = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('containerTypes')
        .where('name', isEqualTo: name.toLowerCase())
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('A container type with this name already exists');
    }

    final typeData = {
      'name': name.toLowerCase(),
      'displayName': displayName,
      'icon': icon,
      'isDefault': false,
      'allowNested': allowNested,
      'createdAt': Timestamp.fromDate(now),
      'createdBy': creatorUid,
    };

    final docRef = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('containerTypes')
        .add(typeData);

    return docRef.id;
  }

  /// Update a container type
  Future<void> updateContainerType({
    required String householdId,
    required String typeId,
    String? displayName,
    String? icon,
    bool? allowNested,
  }) async {
    final updates = <String, dynamic>{};

    if (displayName != null) updates['displayName'] = displayName;
    if (icon != null) updates['icon'] = icon;
    if (allowNested != null) updates['allowNested'] = allowNested;

    if (updates.isEmpty) return;

    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('containerTypes')
        .doc(typeId)
        .update(updates);
  }

  /// Delete a container type (only if not in use)
  Future<void> deleteContainerType({
    required String householdId,
    required String typeId,
  }) async {
    // Get the type to check if it's default
    final typeDoc = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('containerTypes')
        .doc(typeId)
        .get();

    if (!typeDoc.exists) {
      throw Exception('Container type not found');
    }

    final type = ContainerType.fromFirestore(typeDoc);

    if (type.isDefault) {
      throw Exception('Cannot delete default container types');
    }

    // Check if any containers use this type
    final containersUsingType = await _firestore
        .collection('containers')
        .where('householdId', isEqualTo: householdId)
        .where('containerType', isEqualTo: type.name)
        .limit(1)
        .get();

    if (containersUsingType.docs.isNotEmpty) {
      final count = await _getContainerCountByType(householdId, type.name);
      throw Exception('Cannot delete. $count container(s) use this type. Please reassign them first.');
    }

    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('containerTypes')
        .doc(typeId)
        .delete();
  }

  Future<int> _getContainerCountByType(String householdId, String typeName) async {
    final snapshot = await _firestore
        .collection('containers')
        .where('householdId', isEqualTo: householdId)
        .where('containerType', isEqualTo: typeName)
        .get();
    return snapshot.docs.length;
  }

  // ============ Item Types ============

  /// Get all item types for a household
  Stream<List<ItemType>> getItemTypes(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('itemTypes')
        .orderBy('isDefault', descending: true)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ItemType.fromFirestore(doc))
            .toList());
  }

  /// Add a new custom item type
  Future<String> addItemType({
    required String householdId,
    required String name,
    required String displayName,
    required String icon,
    required String creatorUid,
    int? color,
  }) async {
    final now = DateTime.now();

    // Validate uniqueness
    final existing = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('itemTypes')
        .where('name', isEqualTo: name.toLowerCase())
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('An item type with this name already exists');
    }

    final typeData = {
      'name': name.toLowerCase(),
      'displayName': displayName,
      'icon': icon,
      'color': color,
      'isDefault': false,
      'hasSpecializedForm': false,
      'createdAt': Timestamp.fromDate(now),
      'createdBy': creatorUid,
    };

    final docRef = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('itemTypes')
        .add(typeData);

    return docRef.id;
  }

  /// Update an item type
  Future<void> updateItemType({
    required String householdId,
    required String typeId,
    String? displayName,
    String? icon,
    int? color,
  }) async {
    final updates = <String, dynamic>{};

    if (displayName != null) updates['displayName'] = displayName;
    if (icon != null) updates['icon'] = icon;
    if (color != null) updates['color'] = color;

    if (updates.isEmpty) return;

    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('itemTypes')
        .doc(typeId)
        .update(updates);
  }

  /// Delete an item type (only if not in use)
  Future<void> deleteItemType({
    required String householdId,
    required String typeId,
  }) async {
    // Get the type to check if it's default
    final typeDoc = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('itemTypes')
        .doc(typeId)
        .get();

    if (!typeDoc.exists) {
      throw Exception('Item type not found');
    }

    final type = ItemType.fromFirestore(typeDoc);

    if (type.isDefault) {
      throw Exception('Cannot delete default item types');
    }

    // Check if any items use this type
    final count = await _getItemCountByType(householdId, type.name);

    if (count > 0) {
      throw Exception('Cannot delete. $count item(s) use this type. Please reassign them first.');
    }

    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('itemTypes')
        .doc(typeId)
        .delete();
  }

  Future<int> _getItemCountByType(String householdId, String typeName) async {
    final snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .where('type', isEqualTo: typeName)
        .get();
    return snapshot.docs.length;
  }

  // ============ Seeding Default Types ============

  /// Seed default types for a new household
  Future<void> seedDefaultTypes({
    required String householdId,
    required String creatorUid,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    // Seed container types
    for (var typeData in ContainerType.defaultTypes) {
      final docRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('containerTypes')
          .doc();

      batch.set(docRef, {
        ...typeData,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': creatorUid,
      });
    }

    // Seed item types
    for (var typeData in ItemType.defaultTypes) {
      final docRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('itemTypes')
          .doc();

      batch.set(docRef, {
        ...typeData,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': creatorUid,
      });
    }

    await batch.commit();
  }
}
