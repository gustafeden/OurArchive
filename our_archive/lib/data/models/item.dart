import 'package:cloud_firestore/cloud_firestore.dart';
import 'track.dart';

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

  // Music-specific fields
  final String? artist;
  final String? label;
  final String? releaseYear;
  final String? genre;
  final List<String>? styles;
  final String? catalogNumber;
  final List<String>? format;
  final String? country;
  final String? discogsId;
  final List<Track>? tracks; // Track listing for music albums

  // Game-specific fields
  final String? platform;
  final String? gamePublisher;
  final String? players;

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
    this.artist,
    this.label,
    this.releaseYear,
    this.genre,
    this.styles,
    this.catalogNumber,
    this.format,
    this.country,
    this.discogsId,
    this.tracks,
    this.platform,
    this.gamePublisher,
    this.players,
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
      lastModified: data['lastModified'] != null
          ? (data['lastModified'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
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
      artist: data['artist'],
      label: data['label'],
      releaseYear: data['releaseYear'],
      genre: data['genre'],
      styles: data['styles'] != null
        ? List<String>.from(data['styles'])
        : null,
      catalogNumber: data['catalogNumber'],
      format: data['format'] != null
        ? List<String>.from(data['format'])
        : null,
      country: data['country'],
      discogsId: data['discogsId'],
      tracks: data['tracks'] != null
        ? (data['tracks'] as List<dynamic>)
            .map((t) => Track.fromJson(t as Map<String, dynamic>))
            .toList()
        : null,
      platform: data['platform'],
      gamePublisher: data['gamePublisher'],
      players: data['players'],
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
    'artist': artist,
    'label': label,
    'releaseYear': releaseYear,
    'genre': genre,
    'styles': styles,
    'catalogNumber': catalogNumber,
    'format': format,
    'country': country,
    'discogsId': discogsId,
    'tracks': tracks?.map((t) => t.toJson()).toList(),
    'platform': platform,
    'gamePublisher': gamePublisher,
    'players': players,
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
    String? artist,
    String? label,
    String? releaseYear,
    String? genre,
    List<String>? styles,
    String? catalogNumber,
    List<String>? format,
    String? country,
    String? discogsId,
    List<Track>? tracks,
    String? platform,
    String? gamePublisher,
    String? players,
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
      artist: artist ?? this.artist,
      label: label ?? this.label,
      releaseYear: releaseYear ?? this.releaseYear,
      genre: genre ?? this.genre,
      styles: styles ?? this.styles,
      catalogNumber: catalogNumber ?? this.catalogNumber,
      format: format ?? this.format,
      country: country ?? this.country,
      discogsId: discogsId ?? this.discogsId,
      tracks: tracks ?? this.tracks,
      platform: platform ?? this.platform,
      gamePublisher: gamePublisher ?? this.gamePublisher,
      players: players ?? this.players,
    );
  }
}
