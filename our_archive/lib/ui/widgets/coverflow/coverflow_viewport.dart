import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/item.dart';
import '../../../providers/theme_provider.dart';
import 'coverflow_controller.dart';
import 'coverflow_album_card.dart';

/// Viewport that renders visible CoverFlow items with proper z-sorting
class CoverFlowViewport extends ConsumerStatefulWidget {
  final List<Item> items;
  final CoverFlowController controller;
  final double coverSize;
  final Function(Item item, String householdId)? onItemLongPress;
  final String? householdId;

  const CoverFlowViewport({
    super.key,
    required this.items,
    required this.controller,
    this.coverSize = 240.0,
    this.onItemLongPress,
    this.householdId,
  });

  @override
  ConsumerState<CoverFlowViewport> createState() => _CoverFlowViewportState();
}

class _CoverFlowViewportState extends ConsumerState<CoverFlowViewport> {
  // ============================================================================
  // FLOOR REFLECTION CONFIGURATION - Tune these values!
  // ============================================================================

  // Gradient band opacity (dark horizontal band beneath covers)
  static const double _floorGradientTopOpacity = 0.3;      // Top of gradient (0.0-1.0)
  static const double _floorGradientMidOpacity = 0.15;     // Middle of gradient
  static const double _floorGradientBottomOpacity = 0.0;   // Bottom (fade out)

  // Floor positioning and size
  static const double _floorHeightMultiplier = 0.5;        // Height as fraction of cover size
  static const double _floorVerticalOffset = 0.5;          // Distance below cover (0.5 = right at bottom)

  // Center album reflection
  static const double _reflectionSizeMultiplier = 0.4;     // Size relative to cover (0.4 = 40%)
  static const double _reflectionHeightMultiplier = 0.6;   // How much of reflection to show
  static const double _reflectionOpacity = 0.15;           // Overall opacity (0.0-1.0)
  static const double _reflectionBlurAmount = 10.0;        // Blur radius in pixels
  static const double _reflectionTilt = 0.2;               // Perspective tilt (0.0-1.0)

  // ============================================================================

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    setState(() {
      // Update UI when controller changes
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          'No music found',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate center position for the centered album
        _updateCenterCoverRect(constraints);

        return GestureDetector(
          behavior: HitTestBehavior.opaque, // Ensure gestures are always captured
          onTapUp: (details) {
            _handleTapUp(details, constraints);
          },
          onHorizontalDragUpdate: (details) {
            widget.controller.handlePanUpdate(details, widget.coverSize);
          },
          onHorizontalDragEnd: (details) {
            widget.controller.handlePanEnd(details, widget.coverSize);
          },
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Floor reflection backdrop (rendered first, appears behind)
                if (ref.watch(floorReflectionProvider)) _buildFloorReflection(constraints),

                // Album cards (rendered on top)
                ..._buildVisibleCards(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build visible cards with proper z-sorting
  List<Widget> _buildVisibleCards() {
    final position = widget.controller.position;
    final centerIndex = position.round();
    final useDenseMode = ref.watch(denseCoverFlowProvider);

    // Determine visible range based on orientation and mode
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final visibleRange = isLandscape
        ? (useDenseMode ? 6 : 4) // Dense: ±6, Classic: ±4 in landscape
        : 4; // Portrait: always ±4
    final startIndex = (centerIndex - visibleRange).clamp(0, widget.items.length - 1);
    final endIndex = (centerIndex + visibleRange).clamp(0, widget.items.length - 1);

    // Create list of visible items with their deltas
    final visibleItems = <({int index, Item item, double delta, double absDelta})>[];

    for (int i = startIndex; i <= endIndex; i++) {
      final delta = widget.controller.deltaForIndex(i);
      final absDelta = delta.abs();

      visibleItems.add((
        index: i,
        item: widget.items[i],
        delta: delta,
        absDelta: absDelta,
      ));
    }

    // Sort by absDelta descending (farthest first, center last)
    visibleItems.sort((a, b) => b.absDelta.compareTo(a.absDelta));

    // Build widgets
    return visibleItems.map((itemData) {
      return RepaintBoundary(
        key: ValueKey(itemData.item.id),
        child: CoverFlowAlbumCard(
          item: itemData.item,
          delta: itemData.delta,
          coverSize: widget.coverSize,
          onTap: () => widget.controller.handleTap(itemData.index),
          onLongPress: () {
            if (widget.onItemLongPress != null && widget.householdId != null) {
              widget.onItemLongPress!(itemData.item, widget.householdId!);
            }
          },
        ),
      );
    }).toList();
  }

  /// Handle tap on viewport - determine which album was tapped
  void _handleTapUp(TapUpDetails details, BoxConstraints constraints) {
    final tapX = details.localPosition.dx;
    final centerX = constraints.maxWidth / 2;

    // Calculate approximate album index based on tap position
    // Each album is roughly coverSize * 0.6 apart (accounting for rotation and spacing)
    final relativeX = tapX - centerX;
    final albumSpacing = widget.coverSize * 0.6;
    final approximateOffset = relativeX / albumSpacing;

    // Determine which album index was tapped
    final currentCenter = widget.controller.position;
    final tappedIndex = (currentCenter + approximateOffset).round();

    // Clamp to valid range
    final validIndex = tappedIndex.clamp(0, widget.items.length - 1);

    // Handle the tap
    widget.controller.handleTap(validIndex);
  }

  /// Update the center cover rect for overlay positioning
  void _updateCenterCoverRect(BoxConstraints constraints) {
    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;

    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: widget.coverSize,
      height: widget.coverSize,
    );

    widget.controller.updateCenterCoverRect(rect);
  }

  /// Build the floor reflection backdrop
  Widget _buildFloorReflection(BoxConstraints constraints) {
    // Calculate where the floor should be - at the bottom edge of centered covers
    final centerY = constraints.maxHeight / 2;
    final floorStartY = centerY + (widget.coverSize * _floorVerticalOffset);
    final floorHeight = widget.coverSize * _floorHeightMultiplier;

    return Positioned.fill(
      child: Stack(
        children: [
          // Dark horizontal gradient band (the "floor")
          Positioned(
            left: 0,
            right: 0,
            top: floorStartY,
            height: floorHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: _floorGradientTopOpacity),
                    Colors.black.withValues(alpha: _floorGradientMidOpacity),
                    Colors.black.withValues(alpha: _floorGradientBottomOpacity),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Center album reflection
          _buildCenterAlbumReflection(constraints, floorStartY),
        ],
      ),
    );
  }

  /// Build the blurred reflection of the center album
  Widget _buildCenterAlbumReflection(BoxConstraints constraints, double floorStartY) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final centerIndex = widget.controller.position.round().clamp(0, widget.items.length - 1);
    final centerItem = widget.items[centerIndex];
    final imageUrl = centerItem.coverUrl ?? centerItem.photoThumbPath;

    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final centerX = constraints.maxWidth / 2;
    final reflectionSize = widget.coverSize * _reflectionSizeMultiplier;
    final reflectionHeight = reflectionSize * _reflectionHeightMultiplier;

    return Positioned(
      left: centerX - (reflectionSize / 2),
      top: floorStartY,
      width: reflectionSize,
      height: reflectionHeight,
      child: Transform(
        transform: Matrix4.diagonal3Values(1.0, -1.0, 1.0) // Flip vertically
          ..rotateX(_reflectionTilt), // Perspective tilt
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: _reflectionOpacity,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _reflectionBlurAmount,
              sigmaY: _reflectionBlurAmount,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
