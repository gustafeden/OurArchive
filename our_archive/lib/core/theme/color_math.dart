import 'package:flutter/material.dart';

/// Utility functions for color manipulation using mathematical operations.
/// These functions enable algorithmic color generation from a small base palette.
class ColorMath {
  /// Lightens a color by mixing it with white.
  /// [amount] should be between 0.0 and 1.0 (default 0.1 = 10% lighter).
  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    return Color.lerp(color, Colors.white, amount)!;
  }

  /// Darkens a color by mixing it with black.
  /// [amount] should be between 0.0 and 1.0 (default 0.1 = 10% darker).
  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    return Color.lerp(color, Colors.black, amount)!;
  }

  /// Mixes two colors together.
  /// [amount] controls the blend: 0.0 = all [a], 1.0 = all [b].
  static Color mix(Color a, Color b, double amount) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    return Color.lerp(a, b, amount)!;
  }

  /// Returns a new color with the specified opacity.
  /// [opacity] should be between 0.0 (transparent) and 1.0 (opaque).
  static Color opacity(Color color, double opacity) {
    assert(opacity >= 0 && opacity <= 1, 'Opacity must be between 0 and 1');
    return color.withValues(alpha: opacity);
  }

  /// Increases the saturation of a color.
  /// [amount] should be between 0.0 and 1.0.
  static Color saturate(Color color, double amount) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    final hsv = HSVColor.fromColor(color);
    final newSaturation = (hsv.saturation + amount).clamp(0.0, 1.0);
    return hsv.withSaturation(newSaturation).toColor();
  }

  /// Decreases the saturation of a color.
  /// [amount] should be between 0.0 and 1.0.
  static Color desaturate(Color color, double amount) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    final hsv = HSVColor.fromColor(color);
    final newSaturation = (hsv.saturation - amount).clamp(0.0, 1.0);
    return hsv.withSaturation(newSaturation).toColor();
  }

  /// Shifts the hue of a color by the specified degrees.
  /// [degrees] can be any value; it will be normalized to 0-360.
  static Color hueShift(Color color, double degrees) {
    final hsv = HSVColor.fromColor(color);
    final newHue = (hsv.hue + degrees) % 360;
    return hsv.withHue(newHue).toColor();
  }

  /// Creates a color with adjusted brightness.
  /// [amount] should be between -1.0 (black) and 1.0 (white).
  /// Negative values darken, positive values lighten.
  static Color adjustBrightness(Color color, double amount) {
    if (amount < 0) {
      return darken(color, -amount);
    } else if (amount > 0) {
      return lighten(color, amount);
    }
    return color;
  }

  /// Determines if a color is considered "light" (true) or "dark" (false).
  /// Uses relative luminance calculation per W3C standards.
  static bool isLight(Color color) {
    return color.computeLuminance() > 0.5;
  }

  /// Returns either white or black depending on which has better contrast
  /// with the given background color.
  static Color contrastText(Color backgroundColor) {
    return isLight(backgroundColor) ? Colors.black : Colors.white;
  }
}
