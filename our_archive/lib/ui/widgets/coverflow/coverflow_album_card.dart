import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ionicons/ionicons.dart';
import '../../../data/models/item.dart';

/// Individual album card in the CoverFlow with 3D transforms
class CoverFlowAlbumCard extends StatelessWidget {
  // === ROTATION TUNING CONSTANTS ===
  // Adjust these to change how much albums twist toward center
  static const double _landscapeBaseAngle = 0.20; // ~32° (current)
  static const double _landscapeMaxAngle = 0.70; // ~40° max
  static const double _portraitBaseAngle = 0.99; // ~40° (stronger twist)
  static const double _portraitMaxAngle = 0.99; // ~52° max

  final Item item;
  final double delta; // Distance from center (index - position)
  final double coverSize;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CoverFlowAlbumCard({
    super.key,
    required this.item,
    required this.delta,
    required this.coverSize,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final absDelta = delta.abs();

    // Transform math based on delta
    final scale = _computeScale(absDelta);
    final rotationY = _computeRotation(delta, context);
    final translationX = _computeTranslationX(delta, absDelta);
    final translationZ = _computeTranslationZ(absDelta);
    final opacity = _computeOpacity(absDelta);

    // Build transform matrix
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001) // Perspective
      ..translate(translationX, 0.0, translationZ)
      ..rotateY(rotationY)
      ..scale(scale);

    return Transform(
      transform: matrix,
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: coverSize,
            height: coverSize * 1.5, // Include reflection and text height
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main album cover
                _buildAlbumCover(context, absDelta),

                // Reflection
                if (absDelta < 2.0) _buildReflection(context),

                // Album info (title and artist)
                if (absDelta < 2.0) ...[
                  const SizedBox(height: 12),
                  _buildAlbumInfo(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the main album cover with shadow
  Widget _buildAlbumCover(BuildContext context, double absDelta) {
    final isCentered = absDelta < 0.3;

    return Container(
      width: coverSize,
      height: coverSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: isCentered
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildCoverImage(),
      ),
    );
  }

  /// Build the cover image with fallback
  Widget _buildCoverImage() {
    final imageUrl = item.coverUrl ?? item.photoThumbPath;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[800],
        child: const Center(
          child: Icon(
            Ionicons.disc_outline,
            size: 64,
            color: Colors.white54,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[800],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[800],
        child: const Center(
          child: Icon(
            Ionicons.disc_outline,
            size: 64,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  /// Build subtle reflection below the cover
  Widget _buildReflection(BuildContext context) {
    final imageUrl = item.coverUrl ?? item.photoThumbPath;

    return SizedBox(
      height: coverSize * 0.15, // Subtle reflection
      child: Transform(
        transform: Matrix4.identity()..scale(1.0, -1.0, 1.0), // Flip vertically
        alignment: Alignment.topCenter,
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox(),
                )
              : Container(color: Colors.grey[800]),
        ),
      ),
    );
  }

  /// Build album title and artist info below the cover
  Widget _buildAlbumInfo(BuildContext context) {
    return SizedBox(
      width: coverSize * 1.2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Album title
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Artist name
          if (item.artist != null && item.artist!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.artist!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // Transform calculations

  double _computeScale(double absDelta) {
    const scaleFactor = 0.15;
    const maxDistance = 2.0;
    return 1.0 - (scaleFactor * absDelta.clamp(0.0, maxDistance));
  }

  double _computeRotation(double delta, BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final baseAngle = isPortrait ? _portraitBaseAngle : _landscapeBaseAngle;
    final maxAngle = isPortrait ? _portraitMaxAngle : _landscapeMaxAngle;
    final angle = delta * baseAngle;
    return angle.clamp(-maxAngle, maxAngle);
  }

  double _computeTranslationX(double delta, double absDelta) {
    const itemSpacing = 140.0;
    const extraSpacing = 12.0;
    return delta * (itemSpacing + (extraSpacing * absDelta));
  }

  double _computeTranslationZ(double absDelta) {
    const depthFactor = 40.0;
    const maxDistance = 3.0;
    return -depthFactor * absDelta.clamp(0.0, maxDistance);
  }

  double _computeOpacity(double absDelta) {
    const minOpacity = 0.4;
    const fadeFactor = 0.25;
    return (1.0 - (fadeFactor * absDelta)).clamp(minOpacity, 1.0);
  }
}
