/// Represents book metadata retrieved from external APIs (Google Books, Open Library, Libris)
class BookMetadata {
  final String? title;
  final List<String> authors;
  final String? publisher;
  final String? publishedDate;
  final String isbn;
  final String? description;
  final String? thumbnailUrl;
  final int? pageCount;
  final List<String> categories;

  const BookMetadata({
    this.title,
    this.authors = const [],
    this.publisher,
    this.publishedDate,
    required this.isbn,
    this.description,
    this.thumbnailUrl,
    this.pageCount,
    this.categories = const [],
  });

  /// Creates BookMetadata from Google Books API response
  factory BookMetadata.fromGoogleBooks(Map<String, dynamic> json, String isbn) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? {};

    return BookMetadata(
      title: volumeInfo['title'] as String?,
      authors: (volumeInfo['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      publisher: volumeInfo['publisher'] as String?,
      publishedDate: volumeInfo['publishedDate'] as String?,
      isbn: isbn,
      description: volumeInfo['description'] as String?,
      thumbnailUrl: (volumeInfo['imageLinks'] as Map<String, dynamic>?)?['thumbnail'] as String?,
      pageCount: volumeInfo['pageCount'] as int?,
      categories: (volumeInfo['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Creates BookMetadata from Open Library API response
  factory BookMetadata.fromOpenLibrary(Map<String, dynamic> json, String isbn) {
    return BookMetadata(
      title: json['title'] as String?,
      authors: (json['authors'] as List<dynamic>?)
              ?.map((a) => (a as Map<String, dynamic>)['name'] as String)
              .toList() ??
          [],
      publisher: (json['publishers'] as List<dynamic>?)
              ?.map((p) => (p as Map<String, dynamic>)['name'] as String)
              .join(', '),
      publishedDate: json['publish_date'] as String?,
      isbn: isbn,
      description: json['notes'] as String?,
      thumbnailUrl: (json['cover'] as Map<String, dynamic>?)?['medium'] as String?,
      pageCount: json['number_of_pages'] as int?,
      categories: (json['subjects'] as List<dynamic>?)
              ?.map((s) => (s as Map<String, dynamic>)['name'] as String)
              .toList() ??
          [],
    );
  }

  /// Creates BookMetadata from Libris API response (Kungliga biblioteket)
  factory BookMetadata.fromLibris(Map<String, dynamic> json, String isbn) {
    // Handle creator field - can be string or array
    List<String> authors = [];
    final creator = json['creator'];
    if (creator is String) {
      authors = [creator];
    } else if (creator is List) {
      authors = creator.map((c) => c.toString()).toList();
    }

    // Handle publisher - array, take first non-empty value
    String? publisher;
    final publisherList = json['publisher'] as List<dynamic>?;
    if (publisherList != null) {
      publisher = publisherList
          .map((p) => p.toString())
          .where((p) => p.isNotEmpty)
          .firstOrNull;
    }

    // Handle date - array, take first value
    String? publishedDate;
    final dateList = json['date'] as List<dynamic>?;
    if (dateList != null && dateList.isNotEmpty) {
      publishedDate = dateList.first.toString();
    }

    return BookMetadata(
      title: json['title'] as String?,
      authors: authors,
      publisher: publisher,
      publishedDate: publishedDate,
      isbn: isbn,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnail'] as String?, // Libris uses 'thumbnail' not nested 'cover.url'
      pageCount: json['extent'] as int?, // Libris uses 'extent' for page count
      categories: [], // Libris doesn't include detailed categories in this format
    );
  }

  /// Get a display-friendly author string
  String get authorsDisplay {
    if (authors.isEmpty) return 'Unknown Author';
    if (authors.length == 1) return authors.first;
    if (authors.length == 2) return '${authors[0]} and ${authors[1]}';
    return '${authors[0]} et al.';
  }

  @override
  String toString() {
    return 'BookMetadata(title: $title, authors: $authors, isbn: $isbn)';
  }
}
