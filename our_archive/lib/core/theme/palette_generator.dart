import 'package:flutter/material.dart';
import 'base_colors.dart';
import 'generated_palette.dart';
import 'color_math.dart';

/// Generates a complete GeneratedPalette from a minimal BaseColors input.
///
/// This is where the "tiny palette + math" magic happens.
/// All color derivations follow professional design system principles
/// similar to those used by Spotify, Notion, and Linear.
class PaletteGenerator {
  /// Generates a complete theme palette for light mode.
  static GeneratedPalette generateLight(BaseColors base) {
    return GeneratedPalette(
      // Primary colors
      primary: base.primary,
      primaryContainer: ColorMath.lighten(base.primary, 0.85),
      onPrimary: Colors.white,
      onPrimaryContainer: ColorMath.darken(base.primary, 0.3),

      // Secondary colors
      secondary: base.secondary,
      secondaryContainer: ColorMath.lighten(base.secondary, 0.85),
      onSecondary: Colors.white,
      onSecondaryContainer: ColorMath.darken(base.secondary, 0.3),

      // Tertiary colors
      tertiary: base.tertiary,
      tertiaryContainer: ColorMath.lighten(base.tertiary, 0.85),
      onTertiary: Colors.white,
      onTertiaryContainer: ColorMath.darken(base.tertiary, 0.3),

      // Surface colors - based on neutral
      surface: base.neutral,
      surfaceVariant: ColorMath.darken(base.neutral, 0.05),
      surfaceTint: base.primary,
      onSurface: const Color(0xFF1C1B1F),
      onSurfaceVariant: const Color(0xFF49454F),

      // Background colors
      background: base.neutral,
      onBackground: const Color(0xFF1C1B1F),

      // Outline and border colors
      outline: ColorMath.opacity(ColorMath.darken(base.neutral, 0.4), 0.5),
      outlineVariant: ColorMath.opacity(ColorMath.darken(base.neutral, 0.2), 0.3),

      // Error colors - based on accent
      error: base.accent,
      errorContainer: ColorMath.lighten(base.accent, 0.85),
      onError: Colors.white,
      onErrorContainer: ColorMath.darken(base.accent, 0.3),

      // Success colors - derived from tertiary
      success: base.tertiary,
      successContainer: ColorMath.lighten(base.tertiary, 0.85),
      onSuccess: Colors.white,
      onSuccessContainer: ColorMath.darken(base.tertiary, 0.3),

      // Warning colors - blend of accent and tertiary
      warning: ColorMath.mix(base.accent, base.tertiary, 0.5),
      warningContainer: ColorMath.lighten(
        ColorMath.mix(base.accent, base.tertiary, 0.5),
        0.85,
      ),
      onWarning: Colors.white,
      onWarningContainer: ColorMath.darken(
        ColorMath.mix(base.accent, base.tertiary, 0.5),
        0.3,
      ),

      // Utility colors
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFF313033),
      onInverseSurface: const Color(0xFFF4EFF4),
      inversePrimary: ColorMath.lighten(base.primary, 0.4),
    );
  }

  /// Generates a complete theme palette for dark mode.
  static GeneratedPalette generateDark(BaseColors base) {
    return GeneratedPalette(
      // Primary colors - lighter for dark mode
      primary: ColorMath.lighten(base.primary, 0.2),
      primaryContainer: ColorMath.darken(base.primary, 0.3),
      onPrimary: ColorMath.darken(base.primary, 0.4),
      onPrimaryContainer: ColorMath.lighten(base.primary, 0.7),

      // Secondary colors - lighter for dark mode
      secondary: ColorMath.lighten(base.secondary, 0.2),
      secondaryContainer: ColorMath.darken(base.secondary, 0.3),
      onSecondary: ColorMath.darken(base.secondary, 0.4),
      onSecondaryContainer: ColorMath.lighten(base.secondary, 0.7),

      // Tertiary colors - lighter for dark mode
      tertiary: ColorMath.lighten(base.tertiary, 0.2),
      tertiaryContainer: ColorMath.darken(base.tertiary, 0.3),
      onTertiary: ColorMath.darken(base.tertiary, 0.4),
      onTertiaryContainer: ColorMath.lighten(base.tertiary, 0.7),

      // Surface colors - dark neutral base
      surface: ColorMath.mix(base.neutral, Colors.black, 0.85),
      surfaceVariant: ColorMath.mix(base.neutral, Colors.black, 0.75),
      surfaceTint: ColorMath.lighten(base.primary, 0.2),
      onSurface: const Color(0xFFE6E1E5),
      onSurfaceVariant: const Color(0xFFCAC4D0),

      // Background colors
      background: ColorMath.mix(base.neutral, Colors.black, 0.9),
      onBackground: const Color(0xFFE6E1E5),

      // Outline and border colors
      outline: ColorMath.opacity(Colors.white, 0.3),
      outlineVariant: ColorMath.opacity(Colors.white, 0.15),

      // Error colors
      error: ColorMath.lighten(base.accent, 0.2),
      errorContainer: ColorMath.darken(base.accent, 0.3),
      onError: ColorMath.darken(base.accent, 0.4),
      onErrorContainer: ColorMath.lighten(base.accent, 0.7),

      // Success colors
      success: ColorMath.lighten(base.tertiary, 0.2),
      successContainer: ColorMath.darken(base.tertiary, 0.3),
      onSuccess: ColorMath.darken(base.tertiary, 0.4),
      onSuccessContainer: ColorMath.lighten(base.tertiary, 0.7),

      // Warning colors
      warning: ColorMath.lighten(
        ColorMath.mix(base.accent, base.tertiary, 0.5),
        0.2,
      ),
      warningContainer: ColorMath.darken(
        ColorMath.mix(base.accent, base.tertiary, 0.5),
        0.3,
      ),
      onWarning: ColorMath.darken(
        ColorMath.mix(base.accent, base.tertiary, 0.5),
        0.4,
      ),
      onWarningContainer: ColorMath.lighten(
        ColorMath.mix(base.accent, base.tertiary, 0.5),
        0.7,
      ),

      // Utility colors
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFE6E1E5),
      onInverseSurface: const Color(0xFF313033),
      inversePrimary: base.primary,
    );
  }

  /// Generates the appropriate palette based on brightness.
  static GeneratedPalette generate(BaseColors base, Brightness brightness) {
    return brightness == Brightness.light
        ? generateLight(base)
        : generateDark(base);
  }
}
