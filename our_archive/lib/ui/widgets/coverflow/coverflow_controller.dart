import 'package:flutter/material.dart';

/// Controller for managing CoverFlow state, gestures, and animations
class CoverFlowController extends ChangeNotifier {
  CoverFlowController({
    required this.itemCount,
    required TickerProvider vsync,
    double initialPosition = 0,
  })  : _position = initialPosition,
        _vsync = vsync {
    _animationController = AnimationController(vsync: _vsync);
  }

  final int itemCount;
  final TickerProvider _vsync;
  late AnimationController _animationController;

  // Current continuous position (0.0 = first item centered, 1.0 = second item centered, etc.)
  double _position = 0;
  double get position => _position;

  // Track overlay state
  bool _overlayVisible = false;
  bool get overlayVisible => _overlayVisible;

  // Rect of the currently centered cover (for overlay positioning)
  Rect? _centerCoverRect;
  Rect? get centerCoverRect => _centerCoverRect;

  // Gesture lock (prevent swipes when overlay is visible)
  bool _gesturesLocked = false;
  bool get gesturesLocked => _gesturesLocked;

  // Velocity tracking for fling gestures
  double _velocity = 0;
  double get velocity => _velocity;

  /// Update the position (called during pan gestures)
  void updatePosition(double newPosition) {
    if (_gesturesLocked) {
      return;
    }

    _position = newPosition.clamp(0.0, (itemCount - 1).toDouble());
    notifyListeners();
  }

  /// Set position directly (no animation)
  void jumpToItem(int index) {
    if (_gesturesLocked) return;

    _position = index.toDouble().clamp(0.0, (itemCount - 1).toDouble());
    notifyListeners();
  }

  /// Animate to a specific item with spring animation
  Future<void> animateToItem(int targetIndex) async {
    if (_gesturesLocked) return;

    final target = targetIndex.toDouble().clamp(0.0, (itemCount - 1).toDouble());
    final startPosition = _position;
    final distance = target - startPosition;

    if (distance.abs() < 0.01) return; // Already there

    // Create spring animation
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    animation.addListener(() {
      _position = startPosition + (distance * animation.value);
      notifyListeners();
    });

    _animationController.reset();
    await _animationController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 300),
    );

    animation.removeListener(() {});
  }

  /// Handle fling gesture (ballistic scroll with snap)
  Future<void> fling(double velocity) async {
    if (_gesturesLocked) return;

    _velocity = velocity;

    // Ballistic simulation
    final startPosition = _position;
    final distance = velocity * 0.3; // Scale velocity to distance

    // Animate the fling
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.decelerate,
    );

    animation.addListener(() {
      _position = (startPosition + distance * animation.value)
          .clamp(0.0, (itemCount - 1).toDouble());
      notifyListeners();
    });

    _animationController.reset();
    await _animationController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 400),
    );

    animation.removeListener(() {});

    // Snap to nearest item
    final nearestIndex = _position.round();
    await snapToIndex(nearestIndex);
  }

  /// Snap to the nearest item with spring animation
  Future<void> snapToIndex(int index) async {
    final target = index.toDouble().clamp(0.0, (itemCount - 1).toDouble());

    if ((target - _position).abs() < 0.01) {
      _position = target;
      notifyListeners();
      return;
    }

    final startPosition = _position;
    final distance = target - startPosition;

    // Spring snap animation
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack, // Slight overshoot for spring feel
    );

    animation.addListener(() {
      _position = startPosition + (distance * animation.value);
      notifyListeners();
    });

    _animationController.reset();
    await _animationController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 250),
    );

    animation.removeListener(() {});

    // Ensure we land exactly on the target
    _position = target;
    notifyListeners();
  }

  /// Handle pan update (horizontal drag)
  void handlePanUpdate(DragUpdateDetails details, double itemWidth) {
    if (_gesturesLocked) {
      return;
    }

    // Convert pixels to position change
    final delta = -details.delta.dx / itemWidth;
    updatePosition(_position + delta);
  }

  /// Handle pan end (release with potential fling)
  Future<void> handlePanEnd(DragEndDetails details, double itemWidth) async {
    if (_gesturesLocked) return;

    final velocity = -details.velocity.pixelsPerSecond.dx / itemWidth;

    if (velocity.abs() > 2.0) {
      // Fling gesture
      await fling(velocity);
    } else {
      // Snap to nearest
      await snapToIndex(_position.round());
    }
  }

  /// Handle tap on an item
  void handleTap(int tappedIndex) {
    final delta = (tappedIndex - _position).abs();

    if (delta < 0.3) {
      // Tapped on center item - show track overlay
      showTrackOverlay();
    } else {
      // Tapped on side item - snap to center
      animateToItem(tappedIndex);
    }
  }

  /// Handle long press on center item
  void handleLongPress() {
    final centerIndex = _position.round();
    final delta = (centerIndex - _position).abs();

    if (delta < 0.3) {
      // Long press on center item - navigate to detail screen
      // This will be handled by the screen, not the controller
      notifyListeners();
    }
  }

  /// Show the track overlay
  void showTrackOverlay() {
    _overlayVisible = true;
    _gesturesLocked = true;
    notifyListeners();
  }

  /// Hide the track overlay
  void hideTrackOverlay() {
    _overlayVisible = false;
    _gesturesLocked = false;
    notifyListeners();
  }

  /// Update the center cover rect (called by viewport during layout)
  void updateCenterCoverRect(Rect? rect) {
    _centerCoverRect = rect;
    // Don't notify listeners here - this is called during build
    // The rect is only used for positioning, not for triggering rebuilds
  }

  /// Get the currently centered item index
  int get centeredIndex => _position.round();

  /// Compute delta for an item (used by viewport for transforms)
  double deltaForIndex(int index) {
    return index - _position;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
