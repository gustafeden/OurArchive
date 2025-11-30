import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/item.dart';

/// Individual book cover card with animations
class BookCoverCard extends StatefulWidget {
  final Item book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const BookCoverCard({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<BookCoverCard> createState() => _BookCoverCardState();
}

class _BookCoverCardState extends State<BookCoverCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final authorText = widget.book.authors != null && widget.book.authors!.isNotEmpty
        ? ' by ${widget.book.authors!.join(', ')}'
        : '';

    return Semantics(
      label: 'Book: ${widget.book.title}$authorText',
      button: true,
      child: Tooltip(
        message: '${widget.book.title}$authorText',
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
        scale: _isPressed ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.3 : 0.15),
                blurRadius: _isPressed ? 12 : 6,
                offset: Offset(0, _isPressed ? 6 : 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover image
                _buildCoverImage(),

                // Optional gradient overlay with title
                _buildGradientOverlay(theme),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    final coverUrl = widget.book.coverUrl;

    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Hero(
        tag: 'book_cover_${widget.book.id}',
        child: CachedNetworkImage(
          imageUrl: coverUrl,
          memCacheWidth: 300, // Optimize memory usage
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => _buildFallbackCover(),
        ),
      );
    } else {
      return _buildFallbackCover();
    }
  }

  Widget _buildFallbackCover() {
    // Generate a spine-style fallback cover
    final colors = [
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
    ];

    // Use book title hash to consistently pick a color
    final colorIndex = widget.book.title.hashCode.abs() % colors.length;
    final backgroundColor = colors[colorIndex];

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.book.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (widget.book.authors != null && widget.book.authors!.isNotEmpty)
                  Text(
                    widget.book.authors!.join(', '),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.auto_stories,
            color: Colors.white24,
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay(ThemeData theme) {
    // Optional: Add a subtle gradient overlay at the bottom with title
    // For now, we'll skip this to keep covers clean
    // Can be enabled with a toggle in settings
    return const SizedBox.shrink();
  }
}
