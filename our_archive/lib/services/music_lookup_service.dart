import '../data/models/music_metadata.dart';
import '../data/models/discogs_search_result.dart';
import 'discogs_service.dart';

class MusicLookupService {
  /// Lookup music by barcode with pagination support
  static Future<DiscogsSearchResult> lookupByBarcodeWithPagination(
    String barcode, {
    int page = 1,
    int perPage = 5,
  }) async {
    try {
      final response = await DiscogsService.searchByBarcodeWithPagination(
        barcode,
        page: page,
        perPage: perPage,
      );

      final results = response['results'] as List;
      final paginationData = response['pagination'] as Map<String, dynamic>;

      // Convert all results to MusicMetadata with barcode included
      final musicList = results.map((result) {
        final metadata = MusicMetadata.fromDiscogsJson(result);
        return MusicMetadata(
          title: metadata.title,
          artist: metadata.artist,
          label: metadata.label,
          year: metadata.year,
          genre: metadata.genre,
          styles: metadata.styles,
          catalogNumber: metadata.catalogNumber,
          coverUrl: metadata.coverUrl,
          format: metadata.format,
          country: metadata.country,
          discogsId: metadata.discogsId,
          resourceUrl: metadata.resourceUrl,
          barcode: barcode, // Store the actual scanned barcode
        );
      }).toList();

      final pagination = paginationData.isNotEmpty
          ? PaginationInfo.fromJson(paginationData)
          : PaginationInfo.empty();

      return DiscogsSearchResult(
        results: musicList,
        pagination: pagination,
      );
    } catch (e) {
      return DiscogsSearchResult.empty();
    }
  }

  /// Lookup music by barcode - returns all matching results (backward compatible)
  /// For new code, use lookupByBarcodeWithPagination instead
  static Future<List<MusicMetadata>> lookupByBarcode(String barcode) async {
    final result = await lookupByBarcodeWithPagination(barcode, page: 1, perPage: 5);
    return result.results;
  }

  /// Search for music by text query (title or artist)
  static Future<List<MusicMetadata>> searchByText(String query) async {
    try {
      final results = await DiscogsService.searchByText(query);

      return results
          .map((json) => MusicMetadata.fromDiscogsJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get detailed music information by Discogs release ID
  static Future<MusicMetadata?> getDetailedInfo(String releaseId) async {
    try {
      final result = await DiscogsService.getReleaseDetails(releaseId);

      if (result != null) {
        return MusicMetadata.fromDiscogsJson(result);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
