import 'package:flutter/material.dart';

/// A helper class for performing text-based searches with standardized error handling.
///
/// This utility encapsulates the common pattern used across scanner screens:
/// - Input validation
/// - Loading state management
/// - Error handling with user feedback
/// - Empty results handling
///
/// Usage example:
/// ```dart
/// await TextSearchHelper.performSearch<BookMetadata>(
///   context: context,
///   query: _textSearchController.text,
///   searchFunction: (query) => bookLookupService.searchByText(query),
///   onSearchStart: () => setState(() {
///     _isSearching = true;
///     _searchResults = [];
///   }),
///   onSearchComplete: (results) => setState(() {
///     _searchResults = results;
///     _isSearching = false;
///   }),
///   onSearchError: () => setState(() => _isSearching = false),
///   emptyMessage: 'No books found. Try a different search term.',
///   itemTypeName: 'book title or author',
/// );
/// ```
class TextSearchHelper {
  /// Performs a text search with standardized error handling and user feedback.
  ///
  /// Parameters:
  /// - [context]: BuildContext for showing snackbars
  /// - [query]: The search query string
  /// - [searchFunction]: Async function that performs the actual search
  /// - [onSearchStart]: Callback invoked when search starts (set loading state)
  /// - [onSearchComplete]: Callback invoked with results when search completes
  /// - [onSearchError]: Callback invoked when search errors (clear loading state)
  /// - [emptyMessage]: Message to show when no results are found
  /// - [itemTypeName]: Name of the item type for the validation message (e.g., "book title")
  ///
  /// Returns true if search was successful (with or without results), false if validation failed
  static Future<bool> performSearch<T>({
    required BuildContext context,
    required String query,
    required Future<List<T>> Function(String query) searchFunction,
    required VoidCallback onSearchStart,
    required void Function(List<T> results) onSearchComplete,
    required VoidCallback onSearchError,
    required String emptyMessage,
    required String itemTypeName,
  }) async {
    // Validate input
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a $itemTypeName')),
        );
      }
      return false;
    }

    // Start search
    onSearchStart();

    try {
      // Perform the search
      final results = await searchFunction(trimmedQuery);

      // Check if widget is still mounted
      if (!context.mounted) return true;

      // Update with results
      onSearchComplete(results);

      // Show message if no results
      if (results.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(emptyMessage)),
          );
        }
      }

      return true;
    } catch (e) {
      // Check if widget is still mounted
      if (!context.mounted) return false;

      // Clear loading state
      onSearchError();

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${e.toString()}')),
        );
      }

      return false;
    }
  }

  /// A simpler version that uses setState callback pattern.
  ///
  /// This is a convenience wrapper for the common pattern where you have
  /// isSearching and searchResults state variables.
  ///
  /// Usage example:
  /// ```dart
  /// await TextSearchHelper.performSearchWithState<BookMetadata>(
  ///   context: context,
  ///   query: _textSearchController.text,
  ///   searchFunction: (query) => bookLookupService.searchByText(query),
  ///   setState: setState,
  ///   setIsSearching: (value) => _isSearching = value,
  ///   setSearchResults: (results) => _searchResults = results,
  ///   emptyMessage: 'No books found. Try a different search term.',
  ///   itemTypeName: 'book title or author',
  /// );
  /// ```
  static Future<bool> performSearchWithState<T>({
    required BuildContext context,
    required String query,
    required Future<List<T>> Function(String query) searchFunction,
    required void Function(VoidCallback fn) setState,
    required void Function(bool) setIsSearching,
    required void Function(List<T>) setSearchResults,
    required String emptyMessage,
    required String itemTypeName,
  }) {
    return performSearch<T>(
      context: context,
      query: query,
      searchFunction: searchFunction,
      onSearchStart: () => setState(() {
        setIsSearching(true);
        setSearchResults([]);
      }),
      onSearchComplete: (results) => setState(() {
        setSearchResults(results);
        setIsSearching(false);
      }),
      onSearchError: () => setState(() {
        setIsSearching(false);
      }),
      emptyMessage: emptyMessage,
      itemTypeName: itemTypeName,
    );
  }
}
