import 'package:cloud_firestore/cloud_firestore.dart';

enum SyncStatus { pending, syncing, synced, error }

class Item {
  final String id;
  final String title;
  final String type; // 'pantry', 'tool', 'camera', etc.
  final String location; // DEPRECATED: Use roomId and shelfId instead
  final List<String> tags;
  final int quantity;
  final bool archived;
  final int sortOrder;
  final String? photoPath;
  final String? photoThumbPath;
  final DateTime lastModified;
  final DateTime createdAt;
  final String createdBy;
  final SyncStatus syncStatus;
  final String searchText;
  final int version;
  final DateTime? deletedAt;
  final String? barcode;
  final Map<String, dynamic>? reminder;
  final String? containerId; // Reference to Container (room, shelf, box, fridge, etc.)

  // Book-specific fields
  final List<String>? authors;
  final String? publisher;
  final String? isbn;
  final String? coverUrl;
  final int? pageCount;
  final String? description;

  Item({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.tags,
    this.quantity = 1,
    this.archived = false,
    this.sortOrder = 0,
    this.photoPath,
    this.photoThumbPath,
    required this.lastModified,
    required this.createdAt,
    required this.createdBy,
    this.syncStatus = SyncStatus.synced,
    required this.searchText,
    this.version = 1,
    this.deletedAt,
    this.barcode,
    this.reminder,
    this.containerId,
    this.authors,
    this.publisher,
    this.isbn,
    this.coverUrl,
    this.pageCount,
    this.description,
  });

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Item(
      id: doc.id,
      title: data['title'] ?? '',
      type: data['type'] ?? 'general',
      location: data['location'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      quantity: data['quantity'] ?? 1,
      archived: data['archived'] ?? false,
      sortOrder: data['sortOrder'] ?? 0,
      photoPath: data['photoPath'],
      photoThumbPath: data['photoThumbPath'],
      lastModified: (data['lastModified'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      syncStatus: _parseSyncStatus(data['syncStatus']),
      searchText: data['searchText'] ?? '',
      version: data['version'] ?? 1,
      deletedAt: data['deletedAt'] != null
        ? (data['deletedAt'] as Timestamp).toDate()
        : null,
      barcode: data['barcode'],
      reminder: data['reminder'],
      containerId: data['containerId'],
      authors: data['authors'] != null
        ? List<String>.from(data['authors'])
        : null,
      publisher: data['publisher'],
      isbn: data['isbn'],
      coverUrl: data['coverUrl'],
      pageCount: data['pageCount'],
      description: data['description'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'type': type,
    'location': location,
    'tags': tags,
    'quantity': quantity,
    'archived': archived,
    'sortOrder': sortOrder,
    'photoPath': photoPath,
    'photoThumbPath': photoThumbPath,
    'lastModified': Timestamp.fromDate(lastModified),
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'syncStatus': syncStatus.toString().split('.').last,
    'searchText': searchText,
    'version': version,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'barcode': barcode,
    'reminder': reminder,
    'containerId': containerId,
    'authors': authors,
    'publisher': publisher,
    'isbn': isbn,
    'coverUrl': coverUrl,
    'pageCount': pageCount,
    'description': description,
  };

  static SyncStatus _parseSyncStatus(String? status) {
    switch (status) {
      case 'pending': return SyncStatus.pending;
      case 'syncing': return SyncStatus.syncing;
      case 'error': return SyncStatus.error;
      default: return SyncStatus.synced;
    }
  }

  static String generateSearchText(String title, String type, String location, List<String> tags) {
    final parts = [title, type, location, ...tags];
    return parts.join(' ').toLowerCase();
  }

  Item copyWith({
    String? id,
    String? title,
    String? type,
    String? location,
    List<String>? tags,
    int? quantity,
    bool? archived,
    int? sortOrder,
    String? photoPath,
    String? photoThumbPath,
    DateTime? lastModified,
    DateTime? createdAt,
    String? createdBy,
    SyncStatus? syncStatus,
    String? searchText,
    int? version,
    DateTime? deletedAt,
    String? barcode,
    Map<String, dynamic>? reminder,
    String? containerId,
    List<String>? authors,
    String? publisher,
    String? isbn,
    String? coverUrl,
    int? pageCount,
    String? description,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      quantity: quantity ?? this.quantity,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      photoPath: photoPath ?? this.photoPath,
      photoThumbPath: photoThumbPath ?? this.photoThumbPath,
      lastModified: lastModified ?? this.lastModified,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      syncStatus: syncStatus ?? this.syncStatus,
      searchText: searchText ?? this.searchText,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
      barcode: barcode ?? this.barcode,
      reminder: reminder ?? this.reminder,
      containerId: containerId ?? this.containerId,
      authors: authors ?? this.authors,
      publisher: publisher ?? this.publisher,
      isbn: isbn ?? this.isbn,
      coverUrl: coverUrl ?? this.coverUrl,
      pageCount: pageCount ?? this.pageCount,
      description: description ?? this.description,
    );
  }
}
