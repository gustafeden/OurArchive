class VinylMetadata {
  final String title;
  final String artist;
  final String? label;
  final String? year;
  final String? genre;
  final List<String>? styles;
  final String? catalogNumber;
  final String? coverUrl;
  final List<String>? format;
  final String? country;
  final String? discogsId;
  final String? resourceUrl;
  final String? barcode; // The actual UPC/EAN barcode scanned

  VinylMetadata({
    required this.title,
    required this.artist,
    this.label,
    this.year,
    this.genre,
    this.styles,
    this.catalogNumber,
    this.coverUrl,
    this.format,
    this.country,
    this.discogsId,
    this.resourceUrl,
    this.barcode,
  });

  factory VinylMetadata.fromDiscogsJson(Map<String, dynamic> json) {
    // Parse artist from either 'artist' field or extract from 'title'
    String artist = '';
    String title = json['title'] ?? '';

    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      artist = parts[0].trim();
      title = parts.length > 1 ? parts.sublist(1).join(' - ').trim() : title;
    }

    return VinylMetadata(
      title: title,
      artist: artist,
      label: json['label'] != null && (json['label'] as List).isNotEmpty
          ? json['label'][0]
          : null,
      year: json['year']?.toString(),
      genre: json['genre'] != null && (json['genre'] as List).isNotEmpty
          ? json['genre'][0]
          : null,
      styles: json['style'] != null
          ? List<String>.from(json['style'])
          : null,
      catalogNumber: json['catno'],
      coverUrl: json['thumb'] ?? json['cover_image'],
      format: json['format'] != null
          ? List<String>.from(json['format'])
          : null,
      country: json['country'],
      discogsId: json['id']?.toString(),
      resourceUrl: json['resource_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'label': label,
      'year': year,
      'genre': genre,
      'styles': styles,
      'catalogNumber': catalogNumber,
      'coverUrl': coverUrl,
      'format': format,
      'country': country,
      'discogsId': discogsId,
      'resourceUrl': resourceUrl,
      'barcode': barcode,
    };
  }

  @override
  String toString() {
    return 'VinylMetadata(title: $title, artist: $artist, year: $year, label: $label)';
  }
}
