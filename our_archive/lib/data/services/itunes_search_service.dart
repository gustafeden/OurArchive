import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Service for searching Apple Music/iTunes for track preview URLs
/// Uses the free iTunes Search API (no auth required)
class ITunesSearchService {
  static const String _baseUrl = 'https://itunes.apple.com/search';

  /// Search for tracks by album and artist
  /// Returns a map of track titles to their preview URLs
  static Future<Map<String, String>> searchAlbumPreviews({
    required String albumName,
    String? artistName,
    int limit = 200,
  }) async {
    try {
      // Build search query
      final searchTerms = <String>[];
      if (artistName != null && artistName.isNotEmpty) {
        searchTerms.add(artistName);
      }
      searchTerms.add(albumName);

      final queryParams = {
        'term': searchTerms.join(' '),
        'entity': 'song',
        'limit': limit.toString(),
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        print('[iTunes] Error: HTTP ${response.statusCode}');
        return {};
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;

      if (results == null || results.isEmpty) {
        return {};
      }

      // Build map of track title -> preview URL
      final previewMap = <String, String>{};

      for (final result in results) {
        final trackMap = result as Map<String, dynamic>;

        final trackName = trackMap['trackName'] as String?;
        final previewUrl = trackMap['previewUrl'] as String?;

        if (trackName != null &&
            trackName.isNotEmpty &&
            previewUrl != null &&
            previewUrl.isNotEmpty) {
          // Normalize track name for matching (lowercase, trim)
          final normalizedName = _normalizeTrackName(trackName);
          previewMap[normalizedName] = previewUrl;
        }
      }

      print('[iTunes] Found ${previewMap.length} preview URLs for search');
      return previewMap;
    } catch (e) {
      print('[iTunes] Error searching: $e');
      return {};
    }
  }

  /// Match tracks with their preview URLs
  /// Returns updated tracks with previewUrl filled in
  static List<Track> matchTracksWithPreviews(
    List<Track> tracks,
    Map<String, String> previewMap,
  ) {
    if (previewMap.isEmpty) {
      return tracks;
    }

    return tracks.map((track) {
      // Try exact match first
      final normalizedTitle = _normalizeTrackName(track.title);
      var previewUrl = previewMap[normalizedTitle];

      // If no exact match, try fuzzy matching
      if (previewUrl == null) {
        previewUrl = _fuzzyMatchPreview(normalizedTitle, previewMap);
      }

      if (previewUrl != null) {
        return track.copyWith(previewUrl: previewUrl);
      }

      return track;
    }).toList();
  }

  /// Normalize track name for matching
  static String _normalizeTrackName(String name) {
    return name
        .toLowerCase()
        .trim()
        // Remove common suffixes
        .replaceAll(RegExp(r'\s*\(.*?\)\s*'), '')
        .replaceAll(RegExp(r'\s*\[.*?\]\s*'), '')
        // Remove featured artists
        .replaceAll(RegExp(r'\s*feat\..*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*ft\..*', caseSensitive: false), '')
        // Remove extra whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Fuzzy match track name to preview map
  static String? _fuzzyMatchPreview(
    String normalizedTitle,
    Map<String, String> previewMap,
  ) {
    // Try to find a partial match
    for (final entry in previewMap.entries) {
      final previewTitle = entry.key;

      // Check if titles contain each other (handles remaster versions, etc.)
      if (previewTitle.contains(normalizedTitle) ||
          normalizedTitle.contains(previewTitle)) {
        return entry.value;
      }
    }

    return null;
  }
}
