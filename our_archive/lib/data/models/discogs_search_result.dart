import 'music_metadata.dart';

/// Pagination information from Discogs API responses
class PaginationInfo {
  final int currentPage;
  final int totalPages;
  final int perPage;
  final int totalItems;

  const PaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.perPage,
    required this.totalItems,
  });

  bool get hasMore => currentPage < totalPages;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['page'] ?? 1,
      totalPages: json['pages'] ?? 1,
      perPage: json['per_page'] ?? 0,
      totalItems: json['items'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': currentPage,
      'pages': totalPages,
      'per_page': perPage,
      'items': totalItems,
    };
  }

  /// Creates empty pagination info for when no results are found
  factory PaginationInfo.empty() {
    return const PaginationInfo(
      currentPage: 1,
      totalPages: 1,
      perPage: 0,
      totalItems: 0,
    );
  }
}

/// Search result from Discogs API with pagination info
class DiscogsSearchResult {
  final List<MusicMetadata> results;
  final PaginationInfo pagination;

  const DiscogsSearchResult({
    required this.results,
    required this.pagination,
  });

  /// Creates empty search result
  factory DiscogsSearchResult.empty() {
    return DiscogsSearchResult(
      results: const [],
      pagination: PaginationInfo.empty(),
    );
  }
}
