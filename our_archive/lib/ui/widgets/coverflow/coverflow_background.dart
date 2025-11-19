import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/item.dart';

/// Available background styles for CoverFlow
enum CoverFlowBackgroundStyle {
  /// Soft radial spotlight - subtle gradient like a stage spotlight
  radialSpotlight('Radial Spotlight', 'Subtle spotlight effect');

  final String displayName;
  final String description;

  const CoverFlowBackgroundStyle(this.displayName, this.description);
}

/// Widget that renders the appropriate background based on the selected style
class CoverFlowBackground extends StatelessWidget {
  final CoverFlowBackgroundStyle style;
  final Item? currentItem;
  final double width;
  final double height;

  const CoverFlowBackground({
    super.key,
    required this.style,
    this.currentItem,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return _RadialSpotlightBackground(width: width, height: height);
  }
}

/// Soft radial spotlight background
class _RadialSpotlightBackground extends StatelessWidget {
  final double width;
  final double height;

  const _RadialSpotlightBackground({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            const Color(0xFF111111), // Slightly lighter center
            const Color(0xFF000000), // Pure black mid
            const Color(0xFF000000), // Pure black edge
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
    );
  }
}

/// Blurred album background - shows blurred album art behind the coverflow
class BlurredAlbumBackground extends StatefulWidget {
  final Item? item;
  final double width;
  final double height;

  const BlurredAlbumBackground({
    super.key,
    required this.item,
    required this.width,
    required this.height,
  });

  @override
  State<BlurredAlbumBackground> createState() => _BlurredAlbumBackgroundState();
}

class _BlurredAlbumBackgroundState extends State<BlurredAlbumBackground> {
  Item? _lastItem;

  @override
  Widget build(BuildContext context) {
    // Only update if item actually changed
    if (widget.item != null && widget.item != _lastItem) {
      _lastItem = widget.item;
    }

    final imageUrl = _lastItem?.coverUrl ?? _lastItem?.photoThumbPath;

    if (imageUrl == null || imageUrl.isEmpty) {
      // Fallback to black if no image
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: Stack(
        key: ValueKey(imageUrl), // Force rebuild on image change
        children: [
          // Blurred background image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 400),
              errorWidget: (context, url, error) => Container(
                color: Colors.black,
              ),
              imageBuilder: (context, imageProvider) {
                return Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

