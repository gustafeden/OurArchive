import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/book_metadata.dart';

/// Service for looking up book metadata from external APIs
class BookLookupService {
  final http.Client _httpClient;
  final Map<String, BookMetadata> _cache = {};

  BookLookupService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Look up book by ISBN, with in-memory cache and fallback to multiple APIs:
  /// Google Books -> Open Library -> Libris
  Future<BookMetadata?> lookupBook(String isbn) async {
    // Clean ISBN (remove dashes, spaces)
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');

    // Check cache first
    if (_cache.containsKey(cleanIsbn)) {
      debugPrint('Cache hit for ISBN: $cleanIsbn');
      return _cache[cleanIsbn];
    }

    // Try Google Books first
    try {
      final googleResult = await _fetchFromGoogleBooks(cleanIsbn);
      if (googleResult != null) {
        _cache[cleanIsbn] = googleResult;
        return googleResult;
      }
    } catch (e) {
      // Continue to Open Library if Google fails
      debugPrint('Google Books lookup failed: $e');
    }

    // Fallback to Open Library
    try {
      final openLibraryResult = await _fetchFromOpenLibrary(cleanIsbn);
      if (openLibraryResult != null) {
        _cache[cleanIsbn] = openLibraryResult;
        return openLibraryResult;
      }
    } catch (e) {
      debugPrint('Open Library lookup failed: $e');
    }

    // Final fallback to Libris (Swedish Royal Library)
    try {
      final librisResult = await _fetchFromLibris(cleanIsbn);
      if (librisResult != null) {
        _cache[cleanIsbn] = librisResult;
        return librisResult;
      }
    } catch (e) {
      debugPrint('Libris lookup failed: $e');
    }

    return null;
  }

  /// Fetch book data from Google Books API
  Future<BookMetadata?> _fetchFromGoogleBooks(String isbn) async {
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn',
    );

    final response = await _httpClient.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Google Books API timeout'),
    );

    if (response.statusCode != 200) {
      throw Exception('Google Books API returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final totalItems = json['totalItems'] as int? ?? 0;

    if (totalItems == 0) {
      return null;
    }

    final items = json['items'] as List<dynamic>;
    if (items.isEmpty) {
      return null;
    }

    return BookMetadata.fromGoogleBooks(
      items.first as Map<String, dynamic>,
      isbn,
    );
  }

  /// Fetch book data from Open Library API
  Future<BookMetadata?> _fetchFromOpenLibrary(String isbn) async {
    final url = Uri.parse(
      'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data',
    );

    final response = await _httpClient.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Open Library API timeout'),
    );

    if (response.statusCode != 200) {
      throw Exception('Open Library API returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final bookData = json['ISBN:$isbn'] as Map<String, dynamic>?;

    if (bookData == null) {
      return null;
    }

    return BookMetadata.fromOpenLibrary(bookData, isbn);
  }

  /// Fetch book data from Libris API (Kungliga biblioteket - Swedish Royal Library)
  Future<BookMetadata?> _fetchFromLibris(String isbn) async {
    final query = Uri.encodeComponent('linkisxn:$isbn');
    final url = Uri.parse(
      'http://libris.kb.se/xsearch?query=$query&format=json&database=libris',
    );

    final response = await _httpClient.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Libris API timeout'),
    );

    if (response.statusCode != 200) {
      throw Exception('Libris API returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final xsearch = json['xsearch'] as Map<String, dynamic>?;

    if (xsearch == null) {
      return null;
    }

    final list = xsearch['list'] as List<dynamic>?;
    if (list == null || list.isEmpty) {
      return null;
    }

    final record = list.first as Map<String, dynamic>;
    return BookMetadata.fromLibris(record, isbn);
  }

  /// Dispose of resources
  void dispose() {
    _httpClient.close();
  }
}
