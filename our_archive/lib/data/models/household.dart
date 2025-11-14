import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, String> members; // uid -> role
  final String code;
  final int schemaVersion;

  Household({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.code,
    this.schemaVersion = 1,
  });

  factory Household.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Household(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      members: Map<String, String>.from(data['members'] ?? {}),
      code: data['code'] ?? '',
      schemaVersion: data['schemaVersion'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'members': members,
    'code': code,
    'schemaVersion': schemaVersion,
  };

  bool isOwner(String uid) => members[uid] == 'owner';
  bool isMember(String uid) => members[uid] == 'member';
  bool isPending(String uid) => members[uid] == 'pending';
  bool isViewer(String uid) => members[uid] == 'viewer';
  bool hasAccess(String uid) => members.containsKey(uid) && members[uid] != 'pending';
}
