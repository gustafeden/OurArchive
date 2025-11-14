import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class DiscogsService {
  static final String _token = dotenv.env['DISCOGS_TOKEN'] ?? '';
  static const String _base = "https://api.discogs.com";
  static const Duration _timeout = Duration(seconds: 10);

  // In-memory cache for recent searches
  static final Map<String, dynamic> _cache = {};

  static Map<String, String> get _headers => {
        "User-Agent": "OurArchive/1.0",
        "Authorization": "Discogs token=$_token",
      };

  /// Lookup by barcode
  static Future<Map<String, dynamic>?> searchByBarcode(String barcode) async {
    // Check cache first
    final cacheKey = 'barcode:$barcode';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final url = "$_base/database/search?barcode=$barcode&type=release&per_page=5";
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(_timeout);

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);

      if (data["results"] == null || data["results"].isEmpty) return null;

      final result = data["results"][0];

      // Cache the result
      _cache[cacheKey] = result;

      return result;
    } catch (e) {
      return null;
    }
  }

  /// Fallback search (title/artist)
  static Future<List<dynamic>> searchByText(String query) async {
    // Check cache first
    final cacheKey = 'text:$query';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = "$_base/database/search?q=$encodedQuery&type=release&per_page=10";
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(_timeout);

      if (res.statusCode != 200) return [];

      final results = jsonDecode(res.body)["results"] ?? [];

      // Cache the results
      _cache[cacheKey] = results;

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Get detailed release information by ID
  static Future<Map<String, dynamic>?> getReleaseDetails(String releaseId) async {
    // Check cache first
    final cacheKey = 'release:$releaseId';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final url = "$_base/releases/$releaseId";
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(_timeout);

      if (res.statusCode != 200) return null;

      final result = jsonDecode(res.body);

      // Cache the result
      _cache[cacheKey] = result;

      return result;
    } catch (e) {
      return null;
    }
  }

  /// Clear the cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }
}
