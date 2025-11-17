import 'package:flutter/material.dart';
import 'base_colors.dart';
import 'generated_palette.dart';

/// V2 Palette Generator - Visually optimized for real-world UI patterns.
///
/// This generator produces stable, clean, professional palettes with:
/// - Proper surface elevation hierarchy
/// - Constrained container colors (no washed-out tints)
/// - Softer secondary colors
/// - Neutral-based outlines (never brand-tinted)
/// - Better dark mode (no muddy browns or neon mints)
///
/// Unlike math-heavy generators, this follows Material Design principles
/// and produces visually predictable results across all color inputs.
class PaletteGenerator {
  /// Generates a complete theme palette for light mode.
  static GeneratedPalette generateLight(BaseColors base) {
    return _generate(base, dark: false);
  }

  /// Generates a complete theme palette for dark mode.
  static GeneratedPalette generateDark(BaseColors base) {
    return _generate(base, dark: true);
  }

  /// Generates the appropriate palette based on brightness.
  static GeneratedPalette generate(BaseColors base, Brightness brightness) {
    return brightness == Brightness.light
        ? generateLight(base)
        : generateDark(base);
  }

  // =========================================================================
  // CORE GENERATOR
  // =========================================================================

  static GeneratedPalette _generate(BaseColors base, {required bool dark}) {
    final neutralBase = base.neutral;

    // 1. Generate consistent surface hierarchy (NOT derived from brand colors)
    final background = _surface(neutralBase, dark, level: 0);
    final surface = _surface(neutralBase, dark, level: 1);
    final surfaceLow = _surface(neutralBase, dark, level: 2);
    final surfaceHigh = _surface(neutralBase, dark, level: 3);
    final surfaceHighest = _surface(neutralBase, dark, level: 4);
    final surfaceVariant = _surface(neutralBase, dark, level: 3); // Backwards compat

    // 2. Derive primary colors (polite containers, not aggressive tints)
    final primaryContainer = _container(base.primary, dark);
    final onPrimary = _onColor(base.primary);
    final onPrimaryContainer = _onColor(primaryContainer);

    // 3. Secondary - always softer than primary
    final secondary = _soften(base.secondary);
    final secondaryContainer = _container(secondary, dark);
    final onSecondary = _onColor(secondary);
    final onSecondaryContainer = _onColor(secondaryContainer);

    // 4. Tertiary - subtle variation
    final tertiary = base.tertiary;
    final tertiaryContainer = _container(tertiary, dark);
    final onTertiary = _onColor(tertiary);
    final onTertiaryContainer = _onColor(tertiaryContainer);

    // 5. Outlines - ALWAYS neutral, NEVER brand-tinted
    final outline = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.12);

    final outlineVariant = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    // 6. Text colors with correct contrast
    final onSurface = _onColor(surface);
    final onSurfaceVariant = onSurface.withValues(alpha: 0.65);
    final onBackground = _onColor(background);

    // 7. Error colors (from accent)
    final error = base.accent;
    final errorContainer = _container(error, dark);
    final onError = _onColor(error);
    final onErrorContainer = _onColor(errorContainer);

    // 8. Success colors (from tertiary with adjustments)
    final success = _adjustForSuccess(base.tertiary, dark);
    final successContainer = _container(success, dark);
    final onSuccess = _onColor(success);
    final onSuccessContainer = _onColor(successContainer);

    // 9. Warning colors (blend of accent and tertiary)
    final warning = _blend(base.accent, base.tertiary, 0.5);
    final warningContainer = _container(warning, dark);
    final onWarning = _onColor(warning);
    final onWarningContainer = _onColor(warningContainer);

    // 10. Utility colors
    final shadow = Colors.black;
    final scrim = Colors.black;
    final inverseSurface = dark ? const Color(0xFFE6E1E5) : const Color(0xFF313033);
    final onInverseSurface = dark ? const Color(0xFF313033) : const Color(0xFFE6E1E5);
    final inversePrimary = dark ? base.primary : _lighten(base.primary, 0.4);

    return GeneratedPalette(
      primary: base.primary,
      primaryContainer: primaryContainer,
      onPrimary: onPrimary,
      onPrimaryContainer: onPrimaryContainer,

      secondary: secondary,
      secondaryContainer: secondaryContainer,
      onSecondary: onSecondary,
      onSecondaryContainer: onSecondaryContainer,

      tertiary: tertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiary: onTertiary,
      onTertiaryContainer: onTertiaryContainer,

      surface: surface,
      surfaceContainerLowest: background,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      surfaceVariant: surfaceVariant,
      surfaceTint: base.primary,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,

      background: background,
      onBackground: onBackground,

      outline: outline,
      outlineVariant: outlineVariant,

      error: error,
      errorContainer: errorContainer,
      onError: onError,
      onErrorContainer: onErrorContainer,

      success: success,
      successContainer: successContainer,
      onSuccess: onSuccess,
      onSuccessContainer: onSuccessContainer,

      warning: warning,
      warningContainer: warningContainer,
      onWarning: onWarning,
      onWarningContainer: onWarningContainer,

      shadow: shadow,
      scrim: scrim,
      inverseSurface: inverseSurface,
      onInverseSurface: onInverseSurface,
      inversePrimary: inversePrimary,
    );
  }

  // =========================================================================
  // HELPER FUNCTIONS - The "opinionated" color math
  // =========================================================================

  /// Generates a surface color at a specific elevation level.
  /// Level 0 = background, Level 4 = highest elevation.
  ///
  /// IMPORTANT: Never tints with brand colors. Pure neutral progression.
  static Color _surface(Color neutral, bool dark, {required int level}) {
    final hsl = HSLColor.fromColor(neutral);

    if (dark) {
      // Dark mode: Start darker, step up in lightness
      final baseLightness = 0.08; // Not pure black (0.02 too dark)
      final delta = level * 0.04; // Gentle steps
      return hsl
          .withLightness((baseLightness + delta).clamp(0.05, 0.25))
          .toColor();
    } else {
      // Light mode: Start light, step down slightly
      final baseLightness = hsl.lightness.clamp(0.92, 0.98);
      final delta = level * -0.02; // Subtle differentiation
      return hsl
          .withLightness((baseLightness + delta).clamp(0.85, 0.98))
          .toColor();
    }
  }

  /// Creates a container color that's subtle, not washed out.
  /// Light mode: Slightly darker. Dark mode: Slightly lighter.
  static Color _container(Color c, bool dark) {
    final hsl = HSLColor.fromColor(c);

    if (dark) {
      // Dark mode: Lighten modestly, reduce saturation
      return hsl
          .withLightness((hsl.lightness + 0.15).clamp(0.15, 0.35))
          .withSaturation((hsl.saturation * 0.7).clamp(0.2, 1.0))
          .toColor();
    } else {
      // Light mode: Darken slightly, reduce saturation
      return hsl
          .withLightness((hsl.lightness - 0.12).clamp(0.80, 0.95))
          .withSaturation((hsl.saturation * 0.4).clamp(0.1, 1.0))
          .toColor();
    }
  }

  /// Softens a color by reducing saturation and adjusting lightness.
  /// Used for secondary colors to prevent them from competing with primary.
  static Color _soften(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 0.55).clamp(0.1, 1.0))
        .withLightness((hsl.lightness + 0.08).clamp(0.3, 0.7))
        .toColor();
  }

  /// Determines the correct text color (black or white) for a given background.
  /// Uses W3C relative luminance calculation.
  static Color _onColor(Color bg) {
    final lum = bg.computeLuminance();
    return lum > 0.4 ? Colors.black : Colors.white;
  }

  /// Lightens a color by mixing with white.
  static Color _lighten(Color c, double amount) {
    return Color.lerp(c, Colors.white, amount)!;
  }

  /// Blends two colors together.
  static Color _blend(Color a, Color b, double amount) {
    return Color.lerp(a, b, amount)!;
  }

  /// Adjusts tertiary color to be more suitable for success states.
  /// Makes it greener if it isn't already.
  static Color _adjustForSuccess(Color c, bool dark) {
    final hsl = HSLColor.fromColor(c);

    // If already greenish (hue 90-150), use as-is
    if (hsl.hue >= 90 && hsl.hue <= 150) {
      return c;
    }

    // Otherwise shift toward green (120°)
    return hsl
        .withHue(120)
        .withSaturation((hsl.saturation * 0.8).clamp(0.4, 0.9))
        .toColor();
  }
}
