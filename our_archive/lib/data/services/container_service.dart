import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/container.dart' as model;

class ContainerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new container
  Future<String> createContainer({
    required String householdId,
    required String name,
    required String containerType,
    required String creatorUid,
    String? parentId,
    String? description,
    String? icon,
    String? photoPath,
    String? photoThumbPath,
  }) async {
    final now = DateTime.now();

    final containerData = {
      'name': name,
      'householdId': householdId,
      'parentId': parentId,
      'containerType': containerType,
      'description': description,
      'icon': icon,
      'photoPath': photoPath,
      'photoThumbPath': photoThumbPath,
      'createdAt': Timestamp.fromDate(now),
      'lastModified': Timestamp.fromDate(now),
      'createdBy': creatorUid,
      'sortOrder': 0,
    };

    final docRef = await _firestore.collection('containers').add(containerData);
    return docRef.id;
  }

  // Get top-level containers (rooms) for a household
  Stream<List<model.Container>> getTopLevelContainers(String householdId) {
    return _firestore
        .collection('containers')
        .where('householdId', isEqualTo: householdId)
        .where('parentId', isNull: true)
        .orderBy('sortOrder')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => model.Container.fromFirestore(doc))
            .toList());
  }

  // Get child containers for a parent container
  Stream<List<model.Container>> getChildContainers(String parentId, String householdId) {
    return _firestore
        .collection('containers')
        .where('householdId', isEqualTo: householdId)
        .where('parentId', isEqualTo: parentId)
        .orderBy('sortOrder')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => model.Container.fromFirestore(doc))
            .toList());
  }

  // Get all containers for a household (flat list)
  Stream<List<model.Container>> getAllContainers(String householdId) {
    return _firestore
        .collection('containers')
        .where('householdId', isEqualTo: householdId)
        .orderBy('sortOrder')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => model.Container.fromFirestore(doc))
            .toList());
  }

  // Update container
  Future<void> updateContainer({
    required String containerId,
    String? name,
    String? containerType,
    String? description,
    String? icon,
    String? photoPath,
    String? photoThumbPath,
    int? sortOrder,
    String? parentId,
  }) async {
    final updates = <String, dynamic>{
      'lastModified': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (containerType != null) updates['containerType'] = containerType;
    if (description != null) updates['description'] = description;
    if (icon != null) updates['icon'] = icon;
    if (photoPath != null) updates['photoPath'] = photoPath;
    if (photoThumbPath != null) updates['photoThumbPath'] = photoThumbPath;
    if (sortOrder != null) updates['sortOrder'] = sortOrder;
    if (parentId != null) updates['parentId'] = parentId;

    await _firestore.collection('containers').doc(containerId).update(updates);
  }

  // Delete container
  Future<void> deleteContainer(String containerId, String householdId) async {
    // Check if container has child containers - filter by household too
    final childrenSnapshot = await _firestore
        .collection('containers')
        .where('householdId', isEqualTo: householdId)
        .where('parentId', isEqualTo: containerId)
        .limit(1)
        .get();

    if (childrenSnapshot.docs.isNotEmpty) {
      throw Exception(
          'Cannot delete container with nested containers. Delete or move children first.');
    }

    // Check if container has items - query the household's items collection
    final itemsSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('items')
        .where('containerId', isEqualTo: containerId)
        .limit(1)
        .get();

    if (itemsSnapshot.docs.isNotEmpty) {
      throw Exception('Cannot delete container with items. Move items first.');
    }

    await _firestore.collection('containers').doc(containerId).delete();
  }

  // Get single container
  Future<model.Container?> getContainer(String containerId) async {
    final doc = await _firestore.collection('containers').doc(containerId).get();
    if (!doc.exists) return null;
    return model.Container.fromFirestore(doc);
  }

  // Get container path (breadcrumb trail from root to container)
  Future<List<model.Container>> getContainerPath(String containerId) async {
    final path = <model.Container>[];
    String? currentId = containerId;

    while (currentId != null) {
      final container = await getContainer(currentId);
      if (container == null) break;

      path.insert(0, container);
      currentId = container.parentId;
    }

    return path;
  }

  // Move container to different parent
  Future<void> moveContainer({
    required String containerId,
    String? newParentId, // null to move to top level
  }) async {
    await _firestore.collection('containers').doc(containerId).update({
      'parentId': newParentId,
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  // Reorder containers within same parent
  Future<void> reorderContainers(List<String> containerIds) async {
    final batch = _firestore.batch();

    for (var i = 0; i < containerIds.length; i++) {
      final containerRef =
          _firestore.collection('containers').doc(containerIds[i]);
      batch.update(containerRef, {
        'sortOrder': i,
        'lastModified': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
