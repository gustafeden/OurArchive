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

  /// Search for books by title and/or author text query
  /// Returns a list of matching books from Google Books and Open Library
  Future<List<BookMetadata>> searchByText(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final results = <BookMetadata>[];

    // Try Google Books text search first
    try {
      final googleResults = await _searchGoogleBooks(query);
      results.addAll(googleResults);
    } catch (e) {
      debugPrint('Google Books text search failed: $e');
    }

    // Add Open Library results if we don't have many from Google
    if (results.length < 5) {
      try {
        final openLibraryResults = await _searchOpenLibrary(query);
        // Avoid duplicates by checking ISBN
        for (final book in openLibraryResults) {
          if (book.isbn != null && !results.any((b) => b.isbn == book.isbn)) {
            results.add(book);
          }
        }
      } catch (e) {
        debugPrint('Open Library text search failed: $e');
      }
    }

    return results;
  }

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

  /// Search Google Books by text query
  Future<List<BookMetadata>> _searchGoogleBooks(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=$encodedQuery&maxResults=10',
    );

    final response = await _httpClient.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Google Books search timeout'),
    );

    if (response.statusCode != 200) {
      throw Exception('Google Books search returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final totalItems = json['totalItems'] as int? ?? 0;

    if (totalItems == 0) {
      return [];
    }

    final items = json['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      return [];
    }

    final results = <BookMetadata>[];
    for (final item in items) {
      try {
        final itemMap = item as Map<String, dynamic>;
        final volumeInfo = itemMap['volumeInfo'] as Map<String, dynamic>? ?? {};

        // Extract ISBN from industryIdentifiers
        String? isbn;
        final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
        if (identifiers != null) {
          for (final id in identifiers) {
            final idMap = id as Map<String, dynamic>;
            final type = idMap['type'] as String?;
            if (type == 'ISBN_13') {
              isbn = idMap['identifier'] as String?;
              break;
            }
          }
          // Fallback to ISBN_10 if no ISBN_13
          if (isbn == null) {
            for (final id in identifiers) {
              final idMap = id as Map<String, dynamic>;
              final type = idMap['type'] as String?;
              if (type == 'ISBN_10') {
                isbn = idMap['identifier'] as String?;
                break;
              }
            }
          }
        }

        // Skip if no ISBN found
        if (isbn == null || isbn.isEmpty) continue;

        final book = BookMetadata.fromGoogleBooks(itemMap, isbn);
        results.add(book);
      } catch (e) {
        debugPrint('Error parsing Google Books search result: $e');
      }
    }

    return results;
  }

  /// Search Open Library by text query
  Future<List<BookMetadata>> _searchOpenLibrary(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://openlibrary.org/search.json?q=$encodedQuery&limit=10&fields=title,author_name,isbn,cover_i,publisher,publish_year,first_publish_year',
    );

    final response = await _httpClient.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Open Library search timeout'),
    );

    if (response.statusCode != 200) {
      throw Exception('Open Library search returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = json['docs'] as List<dynamic>?;

    if (docs == null || docs.isEmpty) {
      return [];
    }

    final results = <BookMetadata>[];
    for (final doc in docs) {
      try {
        final docMap = doc as Map<String, dynamic>;

        // Extract ISBN (preferring ISBN-13, fallback to ISBN-10)
        String? isbn;
        final isbns = docMap['isbn'] as List<dynamic>?;
        if (isbns != null && isbns.isNotEmpty) {
          // Try to find ISBN-13 first
          for (final isbnValue in isbns) {
            final isbnStr = isbnValue.toString();
            if (isbnStr.length == 13) {
              isbn = isbnStr;
              break;
            }
          }
          // Fallback to first ISBN if no ISBN-13 found
          isbn ??= isbns.first.toString();
        }

        // Extract authors
        final authorNames = docMap['author_name'] as List<dynamic>?;
        final authors = authorNames?.map((a) => a.toString()).toList();

        // Extract publisher (take first if multiple)
        final publishers = docMap['publisher'] as List<dynamic>?;
        final publisher = publishers?.isNotEmpty == true
          ? publishers!.first.toString()
          : null;

        // Extract year
        final firstPublishYear = docMap['first_publish_year'] as int?;
        final publishYear = docMap['publish_year'] as List<dynamic>?;
        final year = firstPublishYear?.toString() ??
          (publishYear?.isNotEmpty == true ? publishYear!.first.toString() : null);

        // Build cover URL from cover_i
        final coverId = docMap['cover_i'] as int?;
        final coverUrl = coverId != null
          ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
          : null;

        // Skip if no ISBN found
        if (isbn == null || isbn.isEmpty) continue;

        final book = BookMetadata(
          title: docMap['title'] as String? ?? 'Unknown Title',
          authors: authors ?? [],
          isbn: isbn,
          publisher: publisher,
          publishedDate: year,
          thumbnailUrl: coverUrl,
          description: null, // Search results don't include description
          pageCount: null,
        );

        results.add(book);
      } catch (e) {
        debugPrint('Error parsing Open Library search result: $e');
      }
    }

    return results;
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
