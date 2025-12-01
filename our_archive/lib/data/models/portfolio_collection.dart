import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioCollection {
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? cover;
  final int order;
  final bool visible;
  final DateTime createdAt;
  final DateTime updatedAt;

  PortfolioCollection({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.cover,
    this.order = 0,
    this.visible = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PortfolioCollection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PortfolioCollection(
      id: doc.id,
      title: data['title'] ?? '',
      slug: data['slug'] ?? '',
      description: data['description'],
      cover: data['cover'],
      order: data['order'] ?? 0,
      visible: data['visible'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'slug': slug,
        'description': description,
        'cover': cover,
        'order': order,
        'visible': visible,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  PortfolioCollection copyWith({
    String? title,
    String? slug,
    String? description,
    String? cover,
    int? order,
    bool? visible,
  }) =>
      PortfolioCollection(
        id: id,
        title: title ?? this.title,
        slug: slug ?? this.slug,
        description: description ?? this.description,
        cover: cover ?? this.cover,
        order: order ?? this.order,
        visible: visible ?? this.visible,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
