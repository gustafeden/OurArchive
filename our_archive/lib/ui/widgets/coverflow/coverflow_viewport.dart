import 'package:flutter/material.dart';
import '../../../data/models/item.dart';
import 'coverflow_controller.dart';
import 'coverflow_album_card.dart';

/// Viewport that renders visible CoverFlow items with proper z-sorting
class CoverFlowViewport extends StatefulWidget {
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
  State<CoverFlowViewport> createState() => _CoverFlowViewportState();
}

class _CoverFlowViewportState extends State<CoverFlowViewport> {
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
              children: _buildVisibleCards(),
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

    // Determine visible range (center ± 4 items)
    const visibleRange = 4;
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
}
