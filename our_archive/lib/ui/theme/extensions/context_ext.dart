import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_radius.dart';

/// Critical extension that makes the entire design system ergonomic
///
/// Instead of:
///   padding: const EdgeInsets.all(16)
///   color: Colors.grey[200]
///
/// You can now write:
///   padding: context.spacing.allMd
///   color: context.colors.photoPlaceholder
///
/// This eliminates hundreds of hardcoded values and makes refactoring trivial
extension BuildContextExtensions on BuildContext {
  /// Access custom colors from theme
  /// Usage: context.colors.infoBackground
  AppColors get colors {
    return Theme.of(this).extension<AppColors>() ?? AppColors.light;
  }

  /// Access spacing constants
  /// Usage: context.spacing.md or context.spacing.allMd
  AppSpacing get spacing => const AppSpacing();

  /// Access radius constants
  /// Usage: context.radius.medium or context.radius.mediumRadius
  AppRadius get radius => const AppRadius();

  /// Access text theme (built-in Material)
  /// Usage: context.textTheme.bodyLarge
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Access color scheme (built-in Material 3)
  /// Usage: context.colorScheme.primary
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
