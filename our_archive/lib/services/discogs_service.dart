import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../data/models/discogs_search_result.dart';

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

  /// Lookup by barcode with pagination support
  static Future<Map<String, dynamic>> searchByBarcodeWithPagination(
    String barcode, {
    int page = 1,
    int perPage = 5,
  }) async {
    // Check cache first (include page in cache key)
    final cacheKey = 'barcode:$barcode:page$page:per$perPage';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final url = "$_base/database/search?barcode=$barcode&type=release&per_page=$perPage&page=$page";
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(_timeout);

      if (res.statusCode != 200) {
        return {
          'results': [],
          'pagination': {},
        };
      }

      final data = jsonDecode(res.body);

      final responseData = {
        'results': data["results"] ?? [],
        'pagination': data["pagination"] ?? {},
      };

      // Cache the results
      _cache[cacheKey] = responseData;

      return responseData;
    } catch (e) {
      return {
        'results': [],
        'pagination': {},
      };
    }
  }

  /// Lookup by barcode - returns all matching results (backward compatible)
  /// For new code, use searchByBarcodeWithPagination instead
  static Future<List<Map<String, dynamic>>> searchByBarcode(String barcode) async {
    final result = await searchByBarcodeWithPagination(barcode, page: 1, perPage: 5);
    return List<Map<String, dynamic>>.from(result['results']);
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
