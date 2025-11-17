import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';

/// A reusable widget for displaying text search UI with results list.
///
/// Provides a standardized search interface used across scanner screens
/// with a text field, search button, loading indicator, and results list.
///
/// Usage:
/// ```dart
/// SearchResultsView<BookMetadata>(
///   controller: _textSearchController,
///   labelText: 'Search',
///   hintText: 'Book title or author',
///   isSearching: _isSearching,
///   searchResults: _searchResults,
///   onSearch: _performTextSearch,
///   resultBuilder: (context, book) => ListTile(
///     title: Text(book.title),
///     onTap: () => _handleResultTap(book),
///   ),
/// )
/// ```
class SearchResultsView<T> extends StatelessWidget {
  /// Controller for the search text field
  final TextEditingController controller;

  /// Label text for the search field
  final String labelText;

  /// Hint text for the search field
  final String hintText;

  /// Whether a search is currently in progress
  final bool isSearching;

  /// List of search results to display
  final List<T> searchResults;

  /// Callback when search button is pressed or text is submitted
  final VoidCallback onSearch;

  /// Builder function to create a widget for each search result
  final Widget Function(BuildContext context, T result) resultBuilder;

  const SearchResultsView({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.isSearching,
    required this.searchResults,
    required this.onSearch,
    required this.resultBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: labelText,
                    hintText: hintText,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isSearching ? null : onSearch,
                child: const Icon(Ionicons.search_outline),
              ),
            ],
          ),
        ),
        if (isSearching)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (searchResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return resultBuilder(context, searchResults[index]);
              },
            ),
          ),
      ],
    );
  }
}
