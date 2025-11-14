import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/household.dart';

class HouseholdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate unique 6-character code with checksum
  String generateHouseholdCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    // Generate 5 chars
    final prefix = List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();

    // Add checksum digit
    int sum = 0;
    for (int i = 0; i < prefix.length; i++) {
      sum += chars.indexOf(prefix[i]) * (i + 1);
    }
    final checksum = chars[sum % chars.length];

    return '$prefix$checksum';
  }

  // Create new household
  Future<String> createHousehold({
    required String name,
    required String creatorUid,
  }) async {
    final code = generateHouseholdCode();

    final docRef = await _firestore.collection('households').add({
      'name': name,
      'createdBy': creatorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': {creatorUid: 'owner'},
      'code': code,
      'schemaVersion': 1,
    });

    // Update user's household list
    await _firestore.collection('users').doc(creatorUid).update({
      'households': FieldValue.arrayUnion([docRef.id]),
    });

    return docRef.id;
  }

  // Join household by code
  Future<void> requestJoinByCode({
    required String code,
    required String userId,
  }) async {
    // Find household with this code
    final query = await _firestore
        .collection('households')
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid household code');
    }

    final householdId = query.docs.first.id;
    final household = query.docs.first.data();

    // Check if already member
    if (household['members']?[userId] != null) {
      throw Exception('Already a member of this household');
    }

    // Add as pending
    await _firestore.collection('households').doc(householdId).update({
      'members.$userId': 'pending',
    });
  }

  // Approve pending member
  Future<void> approveMember({
    required String householdId,
    required String memberUid,
    required String approverUid,
  }) async {
    final doc = await _firestore.collection('households').doc(householdId).get();
    final data = doc.data()!;

    // Check approver is owner
    if (data['members'][approverUid] != 'owner') {
      throw Exception('Only owners can approve members');
    }

    // Check member is pending
    if (data['members'][memberUid] != 'pending') {
      throw Exception('User is not pending approval');
    }

    // Update to member
    await _firestore.collection('households').doc(householdId).update({
      'members.$memberUid': 'member',
    });

    // Add to user's household list
    await _firestore.collection('users').doc(memberUid).update({
      'households': FieldValue.arrayUnion([householdId]),
    });
  }

  // Remove member (including pending members)
  Future<void> removeMember({
    required String householdId,
    required String memberUid,
    required String removerUid,
  }) async {
    final doc = await _firestore.collection('households').doc(householdId).get();
    final data = doc.data()!;

    // Check remover is owner
    if (data['members'][removerUid] != 'owner') {
      throw Exception('Only owners can remove members');
    }

    // Don't allow removing the owner
    if (data['members'][memberUid] == 'owner') {
      throw Exception('Cannot remove the household owner');
    }

    // Check member exists
    if (!data['members'].containsKey(memberUid)) {
      throw Exception('User is not a member of this household');
    }

    // Remove from members map
    await _firestore.collection('households').doc(householdId).update({
      'members.$memberUid': FieldValue.delete(),
    });

    // If they were an approved member (not pending), remove from user's household list
    if (data['members'][memberUid] != 'pending') {
      await _firestore.collection('users').doc(memberUid).update({
        'households': FieldValue.arrayRemove([householdId]),
      });
    }
  }

  // Get user's households
  Stream<List<Household>> getUserHouseholds(String userId) {
    return _firestore
        .collection('households')
        .where('members.$userId', whereIn: ['owner', 'member', 'viewer'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Household.fromFirestore(doc))
            .toList());
  }

  // Get pending approvals for owner
  Stream<List<Map<String, String>>> getPendingMembers(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return [];

          final members = Map<String, String>.from(doc.data()!['members'] ?? {});
          final pending = <Map<String, String>>[];

          members.forEach((uid, role) {
            if (role == 'pending') {
              pending.add({'uid': uid, 'role': role});
            }
          });

          return pending;
        });
  }
}
