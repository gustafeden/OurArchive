import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// A tab item for the liquid glass bottom bar
class LiquidGlassTab {
  final String label;
  final IconData icon;
  final IconData? activeIcon;

  const LiquidGlassTab({
    required this.label,
    required this.icon,
    this.activeIcon,
  });
}

/// A wrapper that adds a liquid glass bottom navigation bar overlay.
class LiquidGlassScaffold extends StatefulWidget {
  final List<LiquidGlassTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Widget body;

  const LiquidGlassScaffold({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.body,
  });

  @override
  State<LiquidGlassScaffold> createState() => _LiquidGlassScaffoldState();
}

class _LiquidGlassScaffoldState extends State<LiquidGlassScaffold>
    with SingleTickerProviderStateMixin {
  late AnimationController _lightAnimationController;
  late Animation<double> _lightAnimation;

  static const double _barHeight = 56;
  static const double _barMargin = 16;

  @override
  void initState() {
    super.initState();
    _lightAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _lightAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_lightAnimationController);
  }

  @override
  void dispose() {
    _lightAnimationController.dispose();
    super.dispose();
  }

  bool get _supportsLiquidGlass {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsLiquidGlass) {
      return _buildFallbackScaffold(context);
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBarTotalHeight = _barHeight + _barMargin + bottomPadding;

    // Content scrolls BEHIND the navbar - we just add padding at the bottom
    // of scrollable content so the last items are accessible
    return Stack(
      children: [
        // The body content - extends fully behind navbar
        Positioned.fill(
          child: MediaQuery(
            // Provide the navbar height so scrollviews can add bottom padding
            data: MediaQuery.of(context).copyWith(
              viewPadding: MediaQuery.of(context).viewPadding.copyWith(
                bottom: navBarTotalHeight,
              ),
            ),
            child: widget.body,
          ),
        ),
        // Liquid glass bottom bar overlay - floating on top
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomBar(context, bottomPadding),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, double bottomPadding) {
    return AnimatedBuilder(
      animation: _lightAnimation,
      builder: (context, child) {
        return LiquidGlassLayer(
          settings: LiquidGlassSettings(
            thickness: 16,
            blur: 20,
            lightAngle: _lightAnimation.value,
            chromaticAberration: 0.3,
            saturation: 1.0,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _barMargin,
              _barMargin,
              _barMargin,
              _barMargin + bottomPadding,
            ),
            child: LiquidGlass(
              shape: LiquidRoundedSuperellipse(borderRadius: 28),
              glassContainsChild: false,
              child: SizedBox(
                height: _barHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (int i = 0; i < widget.tabs.length; i++)
                      _buildTab(context, i),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final tab = widget.tabs[index];
    final isSelected = index == widget.selectedIndex;

    final selectedColor = CupertinoColors.activeBlue;
    final unselectedColor = CupertinoColors.systemGrey;

    return GestureDetector(
      onTap: () => widget.onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? (tab.activeIcon ?? tab.icon) : tab.icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                color: isSelected ? selectedColor : unselectedColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackScaffold(BuildContext context) {
    return Scaffold(
      body: widget.body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.selectedIndex,
        onTap: widget.onTabSelected,
        type: BottomNavigationBarType.fixed,
        items: widget.tabs.map((tab) {
          return BottomNavigationBarItem(
            icon: Icon(tab.icon),
            activeIcon: Icon(tab.activeIcon ?? tab.icon),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }
}
