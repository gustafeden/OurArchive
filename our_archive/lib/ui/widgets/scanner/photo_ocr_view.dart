import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

/// A reusable photo OCR search view for book/item scanning.
///
/// Provides:
/// - Photo capture button
/// - Extracted text display
/// - Search results list
/// - Loading states
/// - Consistent layout and styling
///
/// Usage:
/// ```dart
/// PhotoOcrView<BookMetadata>(
///   isSearching: _isSearching,
///   extractedText: _extractedText,
///   searchResults: _searchResults,
///   onCapturePhoto: _captureAndRecognizeText,
///   onResultTap: _handleSearchResultTap,
///   title: 'Photo Search',
///   description: 'Take a photo of your book cover or spine. We\'ll extract the text and search for matching books.',
///   resultBuilder: (context, book) => ListTile(
///     leading: book.thumbnailUrl != null
///         ? Image.network(book.thumbnailUrl!, width: 40, fit: BoxFit.cover)
///         : const Icon(Ionicons.book_outline),
///     title: Text(book.title ?? 'Unknown Title'),
///     subtitle: book.authors.isNotEmpty ? Text(book.authors.join(', ')) : null,
///   ),
/// )
/// ```
class PhotoOcrView<T> extends StatelessWidget {
  /// Title for the view
  final String title;

  /// Description text explaining how to use photo search
  final String description;

  /// Whether search is currently in progress
  final bool isSearching;

  /// Extracted text from the photo (null if no photo taken yet)
  final String? extractedText;

  /// List of search results
  final List<T> searchResults;

  /// Callback when photo capture button is pressed
  final VoidCallback onCapturePhoto;

  /// Callback when a search result is tapped
  final Function(T) onResultTap;

  /// Builder function for rendering each search result
  final Widget Function(BuildContext, T) resultBuilder;

  const PhotoOcrView({
    super.key,
    required this.title,
    required this.description,
    required this.isSearching,
    required this.extractedText,
    required this.searchResults,
    required this.onCapturePhoto,
    required this.onResultTap,
    required this.resultBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            description,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Capture button
          FilledButton.icon(
            onPressed: isSearching ? null : onCapturePhoto,
            icon: const Icon(Ionicons.camera_outline),
            label: const Text('Take Photo'),
          ),

          // Extracted text display
          if (extractedText != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Extracted text:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              extractedText!,
              style: const TextStyle(fontSize: 12),
            ),
          ],

          // Loading indicator
          if (isSearching)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          // Results list
          else if (searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final result = searchResults[index];
                  return InkWell(
                    onTap: () => onResultTap(result),
                    child: resultBuilder(context, result),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
