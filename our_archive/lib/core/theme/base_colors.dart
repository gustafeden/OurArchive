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

  /// Dusty Rose theme - warm and elegant tones.
  static const BaseColors dustyRose = BaseColors(
    primary: Color(0xFF5F5449), // Warm brown-gray
    secondary: Color(0xFF3B6A6C), // Deep teal
    tertiary: Color(0xFFB09398), // Dusty rose
    neutral: Color(0xFFEBFCFB), // Very light cyan
    accent: Color(0xFFCEDFDD), // Light mint
  );

  /// Nature theme - earthy greens and grays.
  static const BaseColors nature = BaseColors(
    primary: Color(0xFF6B8F71), // Sage green
    secondary: Color(0xFF8BA888), // Light sage
    tertiary: Color(0xFF5A7B6F), // Forest green
    neutral: Color(0xFFE8E8E8), // Light gray
    accent: Color(0xFF3F3F3F), // Charcoal
  );

  /// Ocean theme - cool teal and sage tones.
  static const BaseColors ocean = BaseColors(
    primary: Color(0xFF3A606E), // Deep ocean teal
    secondary: Color(0xFF607E7D), // Sage teal
    tertiary: Color(0xFF828E82), // Gray-green
    neutral: Color(0xFFE0E0E0), // Light gray
    accent: Color(0xFFAAAE8E), // Olive sage
  );

  /// Coastal theme - soft coastal colors.
  static const BaseColors coastal = BaseColors(
    primary: Color(0xFF6B9080), // Sea green
    secondary: Color(0xFFA4C3B2), // Soft sage
    tertiary: Color(0xFFCCE3DE), // Pale mint
    neutral: Color(0xFFEAF4F4), // Very light cyan
    accent: Color(0xFFF6FFF8), // Off-white green
  );

  /// Sunset theme - warm and vibrant.
  static const BaseColors sunset = BaseColors(
    primary: Color(0xFFE76F51), // Coral
    secondary: Color(0xFFF4A261), // Sandy orange
    tertiary: Color(0xFFE9C46A), // Warm yellow
    neutral: Color(0xFFF8F9FA), // Off-white
    accent: Color(0xFF264653), // Deep teal
  );

  /// Forest theme - rich natural greens.
  static const BaseColors forest = BaseColors(
    primary: Color(0xFF2D6A4F), // Forest green
    secondary: Color(0xFF40916C), // Medium green
    tertiary: Color(0xFF52B788), // Light green
    neutral: Color(0xFFF1F8F4), // Pale green-white
    accent: Color(0xFFB7E4C7), // Mint green
  );

  /// Berry theme - rich purples and pinks.
  static const BaseColors berry = BaseColors(
    primary: Color(0xFF7209B7), // Deep purple
    secondary: Color(0xFFB5179E), // Magenta
    tertiary: Color(0xFFF72585), // Hot pink
    neutral: Color(0xFFF8F9FA), // Off-white
    accent: Color(0xFF4CC9F0), // Cyan accent
  );

  /// Refined Teal - professional dark teal with vibrant accents.
  static const BaseColors refinedTeal = BaseColors(
    primary: Color(0xFF00796B), // Deep teal
    secondary: Color(0xFF00BFA5), // Bright teal
    tertiary: Color(0xFF4CAF50), // Green
    neutral: Color(0xFF121416), // Very dark gray
    accent: Color(0xFFFF8A1E), // Orange
  );

  /// Warm Clay - earthy browns with warm tones.
  static const BaseColors warmClay = BaseColors(
    primary: Color(0xFFB75A3B), // Clay brown
    secondary: Color(0xFFE9A87A), // Light terracotta
    tertiary: Color(0xFFC1916F), // Warm tan
    neutral: Color(0xFF151617), // Dark charcoal
    accent: Color(0xFFA35A2A), // Rust
  );

  /// Muted Modern - sophisticated muted teals and grays.
  static const BaseColors mutedModern = BaseColors(
    primary: Color(0xFF2E7D7C), // Muted teal
    secondary: Color(0xFF7FB0AD), // Soft cyan
    tertiary: Color(0xFFAEB8B6), // Cool gray
    neutral: Color(0xFF141617), // Dark slate
    accent: Color(0xFFD88C6A), // Soft coral
  );

  /// Contrast Dark - high contrast dark theme with vibrant greens.
  static const BaseColors contrastDark = BaseColors(
    primary: Color(0xFF16A085), // Deep cyan
    secondary: Color(0xFF1ABC9C), // Turquoise
    tertiary: Color(0xFF2ECC71), // Emerald green
    neutral: Color(0xFF0D0F10), // Near black
    accent: Color(0xFFFF6B4A), // Coral red
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
