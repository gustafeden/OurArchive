import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Track candidate for scoring
class _TrackCandidate {
  final String previewUrl;
  final String trackName;
  final String collectionName;
  final double score;

  _TrackCandidate({
    required this.previewUrl,
    required this.trackName,
    required this.collectionName,
    required this.score,
  });
}

/// Album context to determine what type of versions to prefer
class _AlbumContext {
  final String type; // 'live', 'acoustic', 'studio', 'deluxe', etc.
  final bool isLive;
  final bool isAcoustic;
  final bool isDeluxe;
  final bool isRemaster;

  _AlbumContext({
    required this.type,
    this.isLive = false,
    this.isAcoustic = false,
    this.isDeluxe = false,
    this.isRemaster = false,
  });
}

/// Service for searching Apple Music/iTunes for track preview URLs
/// Uses the free iTunes Search API (no auth required)
class ITunesSearchService {
  static const String _baseUrl = 'https://itunes.apple.com/search';

  /// Strip multi-language metadata from name
  /// E.g., "Leonard Cohen = 李歐納孔*" -> "Leonard Cohen"
  /// E.g., "I'm Your Man = 我是你的男人" -> "I'm Your Man"
  static String _stripMultiLanguageMetadata(String name) {
    // If the name contains "=", take only the part before it
    if (name.contains('=')) {
      return name.split('=').first.trim();
    }
    return name.trim();
  }

  /// Search for tracks by album and artist
  /// Returns a map of track titles to their preview URLs
  static Future<Map<String, String>> searchAlbumPreviews({
    required String albumName,
    String? artistName,
    int limit = 200,
  }) async {
    try {
      print('[iTunes] ==========================================');
      print('[iTunes] STARTING ITUNES SEARCH');
      print('[iTunes] Input - Album: "$albumName"');
      print('[iTunes] Input - Artist: "${artistName ?? "null"}"');

      // Strip multi-language metadata (e.g., "Name = 中文名")
      final cleanAlbumName = _stripMultiLanguageMetadata(albumName);
      final cleanArtistName = artistName != null ? _stripMultiLanguageMetadata(artistName) : null;

      if (cleanAlbumName != albumName) {
        print('[iTunes] Cleaned album name: "$cleanAlbumName"');
      }
      if (artistName != null && cleanArtistName != artistName) {
        print('[iTunes] Cleaned artist name: "$cleanArtistName"');
      }

      // Build search query using cleaned names
      final searchTerms = <String>[];
      if (cleanArtistName != null && cleanArtistName.isNotEmpty) {
        searchTerms.add(cleanArtistName);
      }
      searchTerms.add(cleanAlbumName);

      print('[iTunes] Search terms: ${searchTerms.join(" + ")}');

      final queryParams = {
        'term': searchTerms.join(' '),
        'entity': 'song',
        'limit': limit.toString(),
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      print('[iTunes] Full URL: $uri');
      print('[iTunes] Sending request to iTunes...');

      final response = await http.get(uri);

      print('[iTunes] Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('[iTunes] ❌ ERROR: HTTP ${response.statusCode}');
        print('[iTunes] Response body: ${response.body.substring(0, 200)}...');
        return {};
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;

      print('[iTunes] Results count: ${results?.length ?? 0}');

      if (results == null || results.isEmpty) {
        print('[iTunes] ❌ No results returned from iTunes!');
        print('[iTunes] This means iTunes has no tracks matching this search.');
        return {};
      }

      // Normalize album name for comparison (use cleaned names)
      final normalizedAlbumName = _normalizeAlbumName(cleanAlbumName);
      final normalizedArtistName = cleanArtistName != null ? _normalizeArtistName(cleanArtistName) : null;

      // Detect album type to match appropriate versions (use cleaned name)
      final albumContext = _detectAlbumContext(cleanAlbumName);

      print('[iTunes] Searching for: "$cleanAlbumName" by "$cleanArtistName"');
      print('[iTunes] Album context: ${albumContext.type}');
      print('[iTunes] Normalized album name: "$normalizedAlbumName"');
      if (normalizedArtistName != null) {
        print('[iTunes] Normalized artist name: "$normalizedArtistName"');
      }

      // Build map of track title -> track info (for scoring)
      final candidateTracks = <String, List<_TrackCandidate>>{};
      int skippedCount = 0;
      int totalCount = 0;
      int skippedAlbumMismatch = 0;
      int skippedArtistMismatch = 0;
      int skippedUndesirable = 0;

      for (final result in results) {
        final trackMap = result as Map<String, dynamic>;
        totalCount++;

        final trackName = trackMap['trackName'] as String?;
        final previewUrl = trackMap['previewUrl'] as String?;
        final collectionName = trackMap['collectionName'] as String?;
        final artistNameResult = trackMap['artistName'] as String?;
        final kind = trackMap['kind'] as String?;

        // Skip if no track name or preview URL
        if (trackName == null || trackName.isEmpty || previewUrl == null || previewUrl.isEmpty) {
          continue;
        }

        // Skip non-music items (e.g., music videos)
        if (kind != null && kind != 'song') {
          skippedCount++;
          continue;
        }

        // Verify album name matches (if available)
        bool albumMatches = true;
        if (collectionName != null && collectionName.isNotEmpty) {
          final normalizedCollection = _normalizeAlbumName(collectionName);
          albumMatches = _albumNamesMatch(normalizedAlbumName, normalizedCollection);
        }

        // Verify artist name matches (if we have one and result has one)
        bool artistMatches = true;
        if (normalizedArtistName != null && artistNameResult != null && artistNameResult.isNotEmpty) {
          final normalizedResultArtist = _normalizeArtistName(artistNameResult);
          artistMatches = _artistNamesMatch(normalizedArtistName, normalizedResultArtist);
        }

        // Skip if neither album nor artist matches (too different)
        if (!albumMatches && !artistMatches) {
          if (totalCount <= 10) {
            print('[iTunes]   Skipped "$trackName" - neither album nor artist matches');
            print('[iTunes]     Collection: "$collectionName"');
            print('[iTunes]     Artist: "$artistNameResult"');
          }
          skippedAlbumMismatch++;
          skippedCount++;
          continue;
        }

        // Skip always-undesirable versions (karaoke, ringtone)
        if (_isAlwaysUndesirable(trackName)) {
          if (totalCount <= 10) {
            print('[iTunes]   Skipped "$trackName" - undesirable version');
          }
          skippedUndesirable++;
          skippedCount++;
          continue;
        }

        // Normalize track name for matching
        final normalizedName = _normalizeTrackName(trackName);

        // Score this candidate based on how well it matches what we want
        final score = _scoreTrackCandidate(
          trackName: trackName,
          collectionName: collectionName ?? '',
          albumContext: albumContext,
          albumMatches: albumMatches,
          artistMatches: artistMatches,
        );

        // Add to candidates
        candidateTracks.putIfAbsent(normalizedName, () => []);
        candidateTracks[normalizedName]!.add(_TrackCandidate(
          previewUrl: previewUrl,
          trackName: trackName,
          collectionName: collectionName ?? '',
          score: score,
        ));
      }

      // Select best candidate for each track
      final previewMap = <String, String>{};
      for (final entry in candidateTracks.entries) {
        final trackName = entry.key;
        final candidates = entry.value;

        // Sort by score (highest first)
        candidates.sort((a, b) => b.score.compareTo(a.score));

        // Pick the best one
        if (candidates.isNotEmpty) {
          previewMap[trackName] = candidates.first.previewUrl;

          // Debug: show top candidates for first few tracks
          if (previewMap.length <= 3 && candidates.length > 1) {
            print('[iTunes] Top candidates for "$trackName":');
            for (var i = 0; i < candidates.length && i < 3; i++) {
              final c = candidates[i];
              print('[iTunes]   ${i + 1}. "${c.trackName}" from "${c.collectionName}" (score: ${c.score.toStringAsFixed(1)})');
            }
          }
        }
      }

      print('[iTunes] ==========================================');
      print('[iTunes] Search Summary:');
      print('[iTunes]   Total results: $totalCount');
      print('[iTunes]   Preview URLs found: ${previewMap.length}');
      print('[iTunes]   Skipped: $skippedCount');
      if (skippedCount > 0) {
        print('[iTunes]     - Album/Artist mismatch: $skippedAlbumMismatch');
        print('[iTunes]     - Undesirable versions: $skippedUndesirable');
      }
      print('[iTunes] ==========================================');

      if (previewMap.isEmpty && totalCount > 0) {
        print('[iTunes] ⚠️  WARNING: All tracks were filtered out!');
        print('[iTunes] Check if album/artist names match what iTunes has.');
      }

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
      print('[iTunes] Preview map is empty - no tracks to match');
      return tracks;
    }

    print('[iTunes] Starting track matching...');
    print('[iTunes] Available preview tracks: ${previewMap.keys.take(5).join(", ")}${previewMap.length > 5 ? "... (${previewMap.length} total)" : ""}');

    int matchedCount = 0;
    final unmatchedTracks = <String>[];

    final result = tracks.map((track) {
      print('\n[iTunes] Matching track: "${track.title}"');

      // Try exact match first
      final normalizedTitle = _normalizeTrackName(track.title);
      print('[iTunes]   Normalized to: "$normalizedTitle"');

      var previewUrl = previewMap[normalizedTitle];

      if (previewUrl != null) {
        print('[iTunes]   ✅ Exact match found!');
        matchedCount++;
        return track.copyWith(previewUrl: previewUrl);
      }

      // If no exact match, try fuzzy matching
      print('[iTunes]   No exact match, trying fuzzy match...');
      previewUrl = _fuzzyMatchPreview(normalizedTitle, previewMap);

      if (previewUrl != null) {
        print('[iTunes]   ✅ Fuzzy match found!');
        matchedCount++;
        return track.copyWith(previewUrl: previewUrl);
      } else {
        print('[iTunes]   ❌ No match found');
        unmatchedTracks.add(track.title);
      }

      return track;
    }).toList();

    print('\n[iTunes] ==========================================');
    print('[iTunes] Matched $matchedCount/${tracks.length} tracks with previews');
    if (unmatchedTracks.isNotEmpty) {
      print('[iTunes] Unmatched tracks: ${unmatchedTracks.take(5).join(", ")}${unmatchedTracks.length > 5 ? "..." : ""}');
    }
    print('[iTunes] ==========================================\n');

    return result;
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

  /// Strip all spaces and punctuation for strict comparison
  /// E.g., "Thank You, Stars" -> "thankyoustars"
  static String _strictNormalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); // Keep only letters and numbers
  }

  /// Fuzzy match track name to preview map
  /// Uses multiple strategies: substring, strict normalization, and similarity
  static String? _fuzzyMatchPreview(
    String normalizedTitle,
    Map<String, String> previewMap,
  ) {
    // Strategy 1: Substring match (handles remaster versions, etc.)
    for (final entry in previewMap.entries) {
      final previewTitle = entry.key;

      if (previewTitle.contains(normalizedTitle) ||
          normalizedTitle.contains(previewTitle)) {
        print('[iTunes]     → Substring match: "$previewTitle"');
        return entry.value;
      }
    }

    // Strategy 2: Strict normalized match (handles space/punctuation variations)
    // E.g., "thankyou, stars" matches "thank you, stars"
    final strictTitle = _strictNormalize(normalizedTitle);
    for (final entry in previewMap.entries) {
      final previewTitle = entry.key;
      final strictPreview = _strictNormalize(previewTitle);

      if (strictTitle == strictPreview) {
        print('[iTunes]     → Strict match: "$previewTitle" (space/punctuation normalized)');
        return entry.value;
      }
    }

    // Strategy 3: Similarity match (handles minor typos)
    // Find the best match that's at least 85% similar
    String? bestMatch;
    double bestSimilarity = 0.0;
    String? bestMatchTitle;

    for (final entry in previewMap.entries) {
      final previewTitle = entry.key;
      final similarity = _calculateSimilarity(normalizedTitle, previewTitle);

      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatch = entry.value;
        bestMatchTitle = previewTitle;
      }
    }

    // Accept if similarity is >= 85%
    if (bestSimilarity >= 0.85 && bestMatch != null) {
      print('[iTunes]     → Similarity match: "$bestMatchTitle" (${(bestSimilarity * 100).toStringAsFixed(1)}% similar)');
      return bestMatch;
    } else if (bestSimilarity > 0.7 && bestMatchTitle != null) {
      // Log near-misses to help debug
      print('[iTunes]     → Near-miss: "$bestMatchTitle" (${(bestSimilarity * 100).toStringAsFixed(1)}% similar - threshold is 85%)');
    }

    return null;
  }

  /// Normalize album name for comparison
  static String _normalizeAlbumName(String name) {
    return name
        .toLowerCase()
        .trim()
        // Remove common album suffixes/prefixes
        .replaceAll(RegExp(r'\s*\(deluxe.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(expanded.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(remaster.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(anniversary.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(bonus.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(special.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[.*?\]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Normalize artist name for comparison
  static String _normalizeArtistName(String name) {
    return name
        .toLowerCase()
        .trim()
        // Remove "The" prefix
        .replaceAll(RegExp(r'^the\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Check if two album names match (allowing for variations)
  static bool _albumNamesMatch(String normalized1, String normalized2) {
    // Exact match
    if (normalized1 == normalized2) return true;

    // One contains the other (handles deluxe editions, remasters, etc.)
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
      return true;
    }

    // Check similarity (at least 70% of characters match)
    final similarity = _calculateSimilarity(normalized1, normalized2);
    return similarity >= 0.7;
  }

  /// Check if two artist names match (allowing for variations)
  static bool _artistNamesMatch(String normalized1, String normalized2) {
    // Exact match
    if (normalized1 == normalized2) return true;

    // One contains the other (handles "Artist" vs "The Artist" or featured artists)
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
      return true;
    }

    // Check similarity (at least 80% match for artists - stricter than albums)
    final similarity = _calculateSimilarity(normalized1, normalized2);
    return similarity >= 0.8;
  }

  /// Calculate string similarity (simple Levenshtein ratio)
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    if (longer.length == 0) return 1.0;

    final distance = _levenshteinDistance(longer, shorter);
    return (longer.length - distance) / longer.length;
  }

  /// Calculate Levenshtein distance between two strings
  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Detect album context from album name
  static _AlbumContext _detectAlbumContext(String albumName) {
    final lower = albumName.toLowerCase();

    final isLive = lower.contains('live') && !lower.contains('deliver');
    final isAcoustic = lower.contains('acoustic');
    final isDeluxe = lower.contains('deluxe') || lower.contains('expanded');
    final isRemaster = lower.contains('remaster');

    String type = 'studio';
    if (isLive) {
      type = 'live';
    } else if (isAcoustic) {
      type = 'acoustic';
    } else if (isDeluxe) {
      type = 'deluxe';
    } else if (isRemaster) {
      type = 'remaster';
    }

    return _AlbumContext(
      type: type,
      isLive: isLive,
      isAcoustic: isAcoustic,
      isDeluxe: isDeluxe,
      isRemaster: isRemaster,
    );
  }

  /// Check if a track is ALWAYS undesirable (regardless of context)
  static bool _isAlwaysUndesirable(String trackName) {
    final lower = trackName.toLowerCase();

    // Always skip karaoke/instrumental versions
    if (lower.contains('karaoke')) return true;
    if (lower.contains('instrumental') && !lower.contains('originally')) return true;

    // Always skip ringtone versions
    if (lower.contains('ringtone')) return true;

    // Always skip explicit "cover" or "tribute" versions
    if (lower.contains('tribute')) return true;
    if (lower.contains('in the style of')) return true;

    return false;
  }

  /// Score a track candidate based on how well it matches the album context
  /// Higher score = better match
  static double _scoreTrackCandidate({
    required String trackName,
    required String collectionName,
    required _AlbumContext albumContext,
    required bool albumMatches,
    required bool artistMatches,
  }) {
    double score = 0.0;
    final trackLower = trackName.toLowerCase();
    final collectionLower = collectionName.toLowerCase();

    // Base score: exact album match is best
    if (albumMatches) {
      score += 100.0;
    } else if (artistMatches) {
      score += 50.0; // Same artist, different album - fallback option
    }

    // Context-aware scoring for track versions
    final trackIsLive = trackLower.contains('live') && !trackLower.contains('deliver');
    final trackIsAcoustic = trackLower.contains('acoustic');
    final trackIsRemaster = trackLower.contains('remaster');
    final trackIsExplicit = trackLower.contains('explicit');
    final trackIsRadioEdit = trackLower.contains('radio edit');

    // Match track type to album type
    if (albumContext.isLive) {
      // User has a live album - prefer live tracks
      if (trackIsLive) {
        score += 50.0;
      } else {
        score -= 30.0; // Penalize non-live tracks for live albums
      }
    } else {
      // User has studio album - avoid live tracks
      if (trackIsLive) {
        score -= 50.0;
      } else {
        score += 20.0; // Prefer studio versions
      }
    }

    if (albumContext.isAcoustic) {
      // User has acoustic album - prefer acoustic tracks
      if (trackIsAcoustic) {
        score += 50.0;
      } else {
        score -= 20.0;
      }
    } else {
      // User has non-acoustic album - prefer non-acoustic
      if (trackIsAcoustic) {
        score -= 30.0;
      }
    }

    // Prefer remastered versions if we have a remaster album
    if (albumContext.isRemaster && trackIsRemaster) {
      score += 20.0;
    }

    // General quality preferences
    if (trackIsExplicit) {
      score += 5.0; // Slight preference for explicit over clean
    }

    if (trackIsRadioEdit) {
      score -= 10.0; // Prefer full versions over radio edits
    }

    // Prefer tracks from same collection name
    if (collectionLower.contains(albumContext.type)) {
      score += 10.0;
    }

    return score;
  }
}
