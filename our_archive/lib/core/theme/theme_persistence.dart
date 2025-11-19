import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_colors.dart';

/// Service for persisting theme preferences to local storage.
class ThemePersistence {
  static const String _keyThemePreset = 'theme_preset';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCustomPrimary = 'custom_primary';
  static const String _keyCustomSecondary = 'custom_secondary';
  static const String _keyCustomTertiary = 'custom_tertiary';
  static const String _keyCustomNeutral = 'custom_neutral';
  static const String _keyCustomAccent = 'custom_accent';
  static const String _keyIsCustomTheme = 'is_custom_theme';
  static const String _keyUseDenseCoverFlow = 'use_dense_coverflow';
  static const String _keyCoverFlowBackgroundStyle = 'coverflow_background_style';
  static const String _keyFloorReflection = 'coverflow_floor_reflection';
  static const String _keyCardReflections = 'coverflow_card_reflections';
  static const String _keyBlurredAlbumEffect = 'coverflow_blurred_album_effect';

  /// Loads the saved theme preset name.
  /// Returns 'defaultTheme' if no preference is saved.
  static Future<String> loadThemePreset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemePreset) ?? 'defaultTheme';
  }

  /// Saves the current theme preset name.
  static Future<void> saveThemePreset(String presetName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemePreset, presetName);
  }

  /// Loads the saved theme mode.
  /// Returns ThemeMode.system if no preference is saved.
  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_keyThemeMode) ?? 'system';

    switch (modeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Saves the current theme mode.
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeString;

    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }

    await prefs.setString(_keyThemeMode, modeString);
  }

  /// Checks if a custom theme is being used.
  static Future<bool> isCustomTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsCustomTheme) ?? false;
  }

  /// Saves custom theme colors.
  static Future<void> saveCustomTheme(BaseColors colors) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsCustomTheme, true);
    await prefs.setInt(_keyCustomPrimary, colors.primary.toARGB32());
    await prefs.setInt(_keyCustomSecondary, colors.secondary.toARGB32());
    await prefs.setInt(_keyCustomTertiary, colors.tertiary.toARGB32());
    await prefs.setInt(_keyCustomNeutral, colors.neutral.toARGB32());
    await prefs.setInt(_keyCustomAccent, colors.accent.toARGB32());
  }

  /// Loads saved custom theme colors.
  /// Returns null if no custom theme is saved.
  static Future<BaseColors?> loadCustomTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isCustom = prefs.getBool(_keyIsCustomTheme) ?? false;

    if (!isCustom) return null;

    final primary = prefs.getInt(_keyCustomPrimary);
    final secondary = prefs.getInt(_keyCustomSecondary);
    final tertiary = prefs.getInt(_keyCustomTertiary);
    final neutral = prefs.getInt(_keyCustomNeutral);
    final accent = prefs.getInt(_keyCustomAccent);

    if (primary == null ||
        secondary == null ||
        tertiary == null ||
        neutral == null ||
        accent == null) {
      return null;
    }

    return BaseColors(
      primary: Color(primary),
      secondary: Color(secondary),
      tertiary: Color(tertiary),
      neutral: Color(neutral),
      accent: Color(accent),
    );
  }

  /// Clears the custom theme flag (used when switching to a preset).
  static Future<void> clearCustomTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsCustomTheme, false);
  }

  /// Loads the CoverFlow view mode preference.
  /// Returns true (dense mode) if no preference is saved.
  static Future<bool> loadUseDenseCoverFlow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseDenseCoverFlow) ?? true; // Default to dense
  }

  /// Saves the CoverFlow view mode preference.
  static Future<void> saveUseDenseCoverFlow(bool useDense) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDenseCoverFlow, useDense);
  }

  /// Loads the CoverFlow background style preference.
  /// Returns 'radialSpotlight' if no preference is saved.
  static Future<String> loadCoverFlowBackgroundStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCoverFlowBackgroundStyle) ?? 'radialSpotlight';
  }

  /// Saves the CoverFlow background style preference.
  static Future<void> saveCoverFlowBackgroundStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCoverFlowBackgroundStyle, style);
  }

  /// Loads the floor reflection preference.
  /// Returns true (enabled) if no preference is saved.
  static Future<bool> loadFloorReflection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFloorReflection) ?? true; // Default to enabled
  }

  /// Saves the floor reflection preference.
  static Future<void> saveFloorReflection(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFloorReflection, enabled);
  }

  /// Loads the card reflections preference.
  /// Returns true (enabled) if no preference is saved.
  static Future<bool> loadCardReflections() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCardReflections) ?? true; // Default to enabled
  }

  /// Saves the card reflections preference.
  static Future<void> saveCardReflections(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCardReflections, enabled);
  }

  /// Loads the blurred album background effect preference.
  static Future<bool> loadBlurredAlbumEffect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBlurredAlbumEffect) ?? false; // Default to disabled
  }

  /// Saves the blurred album background effect preference.
  static Future<void> saveBlurredAlbumEffect(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBlurredAlbumEffect, enabled);
  }

  /// Clears all theme preferences (reset to defaults).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyThemePreset);
    await prefs.remove(_keyThemeMode);
    await prefs.remove(_keyCustomPrimary);
    await prefs.remove(_keyCustomSecondary);
    await prefs.remove(_keyCustomTertiary);
    await prefs.remove(_keyCustomNeutral);
    await prefs.remove(_keyCustomAccent);
    await prefs.remove(_keyIsCustomTheme);
    await prefs.remove(_keyUseDenseCoverFlow);
    await prefs.remove(_keyCoverFlowBackgroundStyle);
    await prefs.remove(_keyFloorReflection);
    await prefs.remove(_keyCardReflections);
  }
}
