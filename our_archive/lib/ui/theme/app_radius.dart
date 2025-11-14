import 'package:flutter/widgets.dart';

/// Centralized border radius constants
/// Usage: context.radius.medium or AppRadius.medium
class AppRadius {
  const AppRadius();

  /// 4.0 - Small radius
  static const double small = 4.0;

  /// 8.0 - Medium radius (most common)
  static const double medium = 8.0;

  /// 12.0 - Large radius
  static const double large = 12.0;

  /// 20.0 - Extra large radius (chips, pills)
  static const double xl = 20.0;

  /// 999.0 - Fully rounded (circular)
  static const double pill = 999.0;

  // BorderRadius patterns (as getters for context.radius.mediumRadius syntax)
  BorderRadius get smallRadius => const BorderRadius.all(Radius.circular(small));
  BorderRadius get mediumRadius => const BorderRadius.all(Radius.circular(medium));
  BorderRadius get largeRadius => const BorderRadius.all(Radius.circular(large));
  BorderRadius get xlRadius => const BorderRadius.all(Radius.circular(xl));
  BorderRadius get pillRadius => const BorderRadius.all(Radius.circular(pill));
}
