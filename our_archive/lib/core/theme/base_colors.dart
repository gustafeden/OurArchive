import 'package:flutter/material.dart';

/// The minimal color palette from which all theme colors are mathematically derived.
///
/// This is the only place where you need to define actual color values.
/// Everything else in the app is generated from these 5 colors.
class BaseColors {
  /// Primary color - used for main actions, app bars, focus states.
  final Color primary;

  /// Secondary color - used for supporting elements, FABs, accents.
  final Color secondary;

  /// Tertiary color - used for complementary highlights and variety.
  final Color tertiary;

  /// Neutral color - used for backgrounds, surfaces, and dividers.
  final Color neutral;

  /// Accent color - used for errors, warnings, and special highlights.
  final Color accent;

  const BaseColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.neutral,
    required this.accent,
  });

  /// Default OurArchive theme - teal-based palette.
  static const BaseColors defaultTheme = BaseColors(
    primary: Color(0xFF009688), // Teal
    secondary: Color(0xFF00BCD4), // Cyan
    tertiary: Color(0xFF4CAF50), // Green
    neutral: Color(0xFFF5F5F5), // Light gray
    accent: Color(0xFFFF5722), // Deep orange
  );

  /// Palette 4 theme - from the user's image (earthy tones).
  static const BaseColors palette4 = BaseColors(
    primary: Color(0xFF3D3B00), // Dark olive
    secondary: Color(0xFF7A9189), // Sage green
    tertiary: Color(0xFF9C9B84), // Warm gray
    neutral: Color(0xFFE3DFBC), // Light cream
    accent: Color(0xFFCC6600), // Burnt orange
  );

  /// Dark mode variant - optimized for dark backgrounds.
  static const BaseColors darkTheme = BaseColors(
    primary: Color(0xFF80CBC4), // Light teal
    secondary: Color(0xFF81D4FA), // Light cyan
    tertiary: Color(0xFF81C784), // Light green
    neutral: Color(0xFF212121), // Dark gray
    accent: Color(0xFFFF8A65), // Light coral
  );

  BaseColors copyWith({
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? neutral,
    Color? accent,
  }) {
    return BaseColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      neutral: neutral ?? this.neutral,
      accent: accent ?? this.accent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseColors &&
          runtimeType == other.runtimeType &&
          primary == other.primary &&
          secondary == other.secondary &&
          tertiary == other.tertiary &&
          neutral == other.neutral &&
          accent == other.accent;

  @override
  int get hashCode =>
      primary.hashCode ^
      secondary.hashCode ^
      tertiary.hashCode ^
      neutral.hashCode ^
      accent.hashCode;
}
