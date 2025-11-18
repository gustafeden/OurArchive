import '../data/models/vinyl_metadata.dart';
import 'discogs_service.dart';

class VinylLookupService {
  /// Lookup vinyl by barcode - returns all matching results
  static Future<List<VinylMetadata>> lookupByBarcode(String barcode) async {
    try {
      final results = await DiscogsService.searchByBarcode(barcode);

      if (results.isEmpty) return [];

      // Convert all results to VinylMetadata with barcode included
      return results.map((result) {
        final metadata = VinylMetadata.fromDiscogsJson(result);
        // Create a new instance with the barcode included
        return VinylMetadata(
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
    } catch (e) {
      return [];
    }
  }

  /// Search for vinyl by text query (title or artist)
  static Future<List<VinylMetadata>> searchByText(String query) async {
    try {
      final results = await DiscogsService.searchByText(query);

      return results
          .map((json) => VinylMetadata.fromDiscogsJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get detailed vinyl information by Discogs release ID
  static Future<VinylMetadata?> getDetailedInfo(String releaseId) async {
    try {
      final result = await DiscogsService.getReleaseDetails(releaseId);

      if (result != null) {
        return VinylMetadata.fromDiscogsJson(result);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
