import 'package:flutter/material.dart';

/// A widget that displays a network image with a fallback icon if loading fails.
///
/// Commonly used in preview dialogs for scanned items (books, vinyl, etc.) to show
/// cover art or thumbnail images with graceful error handling.
///
/// Usage:
/// ```dart
/// NetworkImageWithFallback(
///   imageUrl: book.thumbnailUrl,
///   height: 200,
///   fallbackIcon: Ionicons.book_outline,
/// )
/// ```
class NetworkImageWithFallback extends StatelessWidget {
  /// URL of the image to load (can be null or empty)
  final String? imageUrl;

  /// Height of the image
  final double height;

  /// Icon to show if image fails to load or URL is null/empty
  final IconData fallbackIcon;

  /// Size of the fallback icon (defaults to 100)
  final double fallbackIconSize;

  /// Whether to center the image (defaults to true)
  final bool centered;

  const NetworkImageWithFallback({
    super.key,
    required this.imageUrl,
    required this.height,
    required this.fallbackIcon,
    this.fallbackIconSize = 100,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    // If no URL provided, show fallback icon immediately
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    final imageWidget = Image.network(
      imageUrl!,
      height: height,
      errorBuilder: (context, error, stackTrace) => Icon(
        fallbackIcon,
        size: fallbackIconSize,
      ),
    );

    return centered ? Center(child: imageWidget) : imageWidget;
  }

  Widget _buildFallback() {
    final icon = Icon(fallbackIcon, size: fallbackIconSize);
    return centered ? Center(child: icon) : icon;
  }
}
