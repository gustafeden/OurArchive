import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioPhoto {
  final String id;
  final String collectionId;
  final String src;
  final String? caption;
  final String? location;
  final String? notes;
  final bool showExif;
  final ExifData? exif;
  final int order;
  final DateTime createdAt;

  PortfolioPhoto({
    required this.id,
    required this.collectionId,
    required this.src,
    this.caption,
    this.location,
    this.notes,
    this.showExif = true,
    this.exif,
    this.order = 0,
    required this.createdAt,
  });

  factory PortfolioPhoto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PortfolioPhoto(
      id: doc.id,
      collectionId: data['collectionId'] ?? '',
      src: data['src'] ?? '',
      caption: data['caption'],
      location: data['location'],
      notes: data['notes'],
      showExif: data['showExif'] ?? true,
      exif: data['exif'] != null
          ? ExifData.fromMap(Map<String, dynamic>.from(data['exif']))
          : null,
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'collectionId': collectionId,
        'src': src,
        'caption': caption,
        'location': location,
        'notes': notes,
        'showExif': showExif,
        'exif': exif?.toMap(),
        'order': order,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.now(),
      };

  PortfolioPhoto copyWith({
    String? caption,
    String? location,
    String? notes,
    bool? showExif,
    int? order,
  }) =>
      PortfolioPhoto(
        id: id,
        collectionId: collectionId,
        src: src,
        caption: caption ?? this.caption,
        location: location ?? this.location,
        notes: notes ?? this.notes,
        showExif: showExif ?? this.showExif,
        exif: exif,
        order: order ?? this.order,
        createdAt: createdAt,
      );
}

class ExifData {
  final String? camera;
  final String? lens;
  final String? aperture;
  final String? shutter;
  final int? iso;
  final String? focalLength;
  final String? date;

  ExifData({
    this.camera,
    this.lens,
    this.aperture,
    this.shutter,
    this.iso,
    this.focalLength,
    this.date,
  });

  factory ExifData.fromMap(Map<String, dynamic> map) => ExifData(
        camera: map['camera'],
        lens: map['lens'],
        aperture: map['aperture'],
        shutter: map['shutter'],
        iso: map['iso'],
        focalLength: map['focalLength'],
        date: map['date'],
      );

  Map<String, dynamic> toMap() => {
        if (camera != null) 'camera': camera,
        if (lens != null) 'lens': lens,
        if (aperture != null) 'aperture': aperture,
        if (shutter != null) 'shutter': shutter,
        if (iso != null) 'iso': iso,
        if (focalLength != null) 'focalLength': focalLength,
        if (date != null) 'date': date,
      };

  String toDisplayString() {
    final parts = <String>[];
    if (aperture != null) parts.add(aperture!);
    if (shutter != null) parts.add(shutter!);
    if (iso != null) parts.add('ISO $iso');
    if (focalLength != null) parts.add(focalLength!);
    return parts.join(' · ');
  }

  bool get isEmpty =>
      camera == null &&
      lens == null &&
      aperture == null &&
      shutter == null &&
      iso == null &&
      focalLength == null &&
      date == null;
}
