import 'package:flutter/widgets.dart';

/// Centralized spacing constants to replace hardcoded EdgeInsets
/// Usage: context.spacing.md or AppSpacing.md
class AppSpacing {
  const AppSpacing();

  /// 4.0 - Extra small spacing
  static const double xs = 4.0;

  /// 8.0 - Small spacing
  static const double sm = 8.0;

  /// 16.0 - Medium spacing (most common)
  static const double md = 16.0;

  /// 24.0 - Large spacing
  static const double lg = 24.0;

  /// 32.0 - Extra large spacing
  static const double xl = 32.0;

  /// 48.0 - Extra extra large spacing
  static const double xxl = 48.0;

  // Common EdgeInsets patterns (as getters for context.spacing.allMd syntax)
  EdgeInsets get allXs => const EdgeInsets.all(xs);
  EdgeInsets get allSm => const EdgeInsets.all(sm);
  EdgeInsets get allMd => const EdgeInsets.all(md);
  EdgeInsets get allLg => const EdgeInsets.all(lg);
  EdgeInsets get allXl => const EdgeInsets.all(xl);

  EdgeInsets get horizontalMd => const EdgeInsets.symmetric(horizontal: md);
  EdgeInsets get horizontalLg => const EdgeInsets.symmetric(horizontal: lg);
  EdgeInsets get verticalMd => const EdgeInsets.symmetric(vertical: md);
  EdgeInsets get verticalSm => const EdgeInsets.symmetric(vertical: sm);

  EdgeInsets get horizontalMdVerticalSm =>
      const EdgeInsets.symmetric(horizontal: md, vertical: sm);
  EdgeInsets get horizontalMdVerticalMd =>
      const EdgeInsets.symmetric(horizontal: md, vertical: md);

  // Common SizedBox patterns (as getters for context.spacing.gapMd syntax)
  Widget get gapXs => const SizedBox(height: xs, width: xs);
  Widget get gapSm => const SizedBox(height: sm, width: sm);
  Widget get gapMd => const SizedBox(height: md, width: md);
  Widget get gapLg => const SizedBox(height: lg, width: lg);
  Widget get gapXl => const SizedBox(height: xl, width: xl);
}
