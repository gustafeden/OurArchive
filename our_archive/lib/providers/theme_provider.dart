import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/base_colors.dart';
import '../core/theme/theme_builder.dart';
import '../core/theme/theme_persistence.dart';
import '../ui/widgets/coverflow/coverflow_background.dart';

/// Notifier for managing base colors with persistence.
class BaseColorsNotifier extends StateNotifier<BaseColors> {
  BaseColorsNotifier() : super(BaseColors.defaultTheme) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    // Check if using custom theme
    final isCustom = await ThemePersistence.isCustomTheme();

    if (isCustom) {
      final customColors = await ThemePersistence.loadCustomTheme();
      if (customColors != null) {
        state = customColors;
        return;
      }
    }

    // Otherwise load preset
    final presetName = await ThemePersistence.loadThemePreset();
    final preset = ThemePreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => ThemePreset.defaultTheme,
    );
    state = preset.colors;
  }

  Future<void> setPreset(ThemePreset preset) async {
    state = preset.colors;
    await ThemePersistence.clearCustomTheme();
    await ThemePersistence.saveThemePreset(preset.name);
  }

  Future<void> setCustom(BaseColors colors) async {
    state = colors;
    await ThemePersistence.saveCustomTheme(colors);
  }
}

/// Notifier for managing theme mode with persistence.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadSavedMode();
  }

  Future<void> _loadSavedMode() async {
    state = await ThemePersistence.loadThemeMode();
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ThemePersistence.saveThemeMode(mode);
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setMode(newMode);
  }
}

/// Notifier for managing CoverFlow view mode with persistence.
class DenseCoverFlowNotifier extends StateNotifier<bool> {
  DenseCoverFlowNotifier() : super(true) {
    _loadSavedMode();
  }

  Future<void> _loadSavedMode() async {
    state = await ThemePersistence.loadUseDenseCoverFlow();
  }

  Future<void> setMode(bool useDense) async {
    state = useDense;
    await ThemePersistence.saveUseDenseCoverFlow(useDense);
  }

  Future<void> toggle() async {
    await setMode(!state);
  }
}

/// Notifier for managing CoverFlow background style with persistence.
class CoverFlowBackgroundStyleNotifier extends StateNotifier<CoverFlowBackgroundStyle> {
  CoverFlowBackgroundStyleNotifier() : super(CoverFlowBackgroundStyle.radialSpotlight) {
    _loadSavedStyle();
  }

  Future<void> _loadSavedStyle() async {
    final styleName = await ThemePersistence.loadCoverFlowBackgroundStyle();
    final style = CoverFlowBackgroundStyle.values.firstWhere(
      (s) => s.name == styleName,
      orElse: () => CoverFlowBackgroundStyle.radialSpotlight,
    );
    state = style;
  }

  Future<void> setStyle(CoverFlowBackgroundStyle style) async {
    state = style;
    await ThemePersistence.saveCoverFlowBackgroundStyle(style.name);
  }
}

/// Notifier for managing floor reflection effect with persistence.
class FloorReflectionNotifier extends StateNotifier<bool> {
  FloorReflectionNotifier() : super(true) {
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    state = await ThemePersistence.loadFloorReflection();
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ThemePersistence.saveFloorReflection(enabled);
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

/// Notifier for managing per-card reflections with persistence.
class CardReflectionsNotifier extends StateNotifier<bool> {
  CardReflectionsNotifier() : super(true) {
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    state = await ThemePersistence.loadCardReflections();
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ThemePersistence.saveCardReflections(enabled);
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

/// Notifier for managing blurred album background effect with persistence.
class BlurredAlbumEffectNotifier extends StateNotifier<bool> {
  BlurredAlbumEffectNotifier() : super(false) {
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    state = await ThemePersistence.loadBlurredAlbumEffect();
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ThemePersistence.saveBlurredAlbumEffect(enabled);
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

/// Provider for the current base color palette.
/// Change this to instantly update the entire app's theme.
final baseColorsProvider =
    StateNotifierProvider<BaseColorsNotifier, BaseColors>((ref) {
  return BaseColorsNotifier();
});

/// Provider for the current theme mode (light/dark/system).
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Provider for the CoverFlow view mode (dense/classic).
final denseCoverFlowProvider =
    StateNotifierProvider<DenseCoverFlowNotifier, bool>((ref) {
  return DenseCoverFlowNotifier();
});

/// Provider for the CoverFlow background style.
final coverFlowBackgroundStyleProvider =
    StateNotifierProvider<CoverFlowBackgroundStyleNotifier, CoverFlowBackgroundStyle>((ref) {
  return CoverFlowBackgroundStyleNotifier();
});

/// Provider for the floor reflection effect.
final floorReflectionProvider =
    StateNotifierProvider<FloorReflectionNotifier, bool>((ref) {
  return FloorReflectionNotifier();
});

/// Provider for per-card reflections.
final cardReflectionsProvider =
    StateNotifierProvider<CardReflectionsNotifier, bool>((ref) {
  return CardReflectionsNotifier();
});

/// Provider for blurred album background effect.
final blurredAlbumEffectProvider =
    StateNotifierProvider<BlurredAlbumEffectNotifier, bool>((ref) {
  return BlurredAlbumEffectNotifier();
});

/// Provider that builds the light theme from the current base colors.
final lightThemeProvider = Provider<ThemeData>((ref) {
  final baseColors = ref.watch(baseColorsProvider);
  return ThemeBuilder.buildLight(baseColors);
});

/// Provider that builds the dark theme from the current base colors.
final darkThemeProvider = Provider<ThemeData>((ref) {
  final baseColors = ref.watch(baseColorsProvider);
  return ThemeBuilder.buildDark(baseColors);
});

/// Available theme presets that users can quickly switch between.
enum ThemePreset {
  defaultTheme('Default', BaseColors.defaultTheme),
  palette4('Earthy', BaseColors.palette4),
  darkTheme('Dark', BaseColors.darkTheme),
  dustyRose('Dusty Rose', BaseColors.dustyRose),
  nature('Nature', BaseColors.nature),
  ocean('Ocean', BaseColors.ocean),
  coastal('Coastal', BaseColors.coastal),
  sunset('Sunset', BaseColors.sunset),
  forest('Forest', BaseColors.forest),
  berry('Berry', BaseColors.berry),
  refinedTeal('Refined Teal', BaseColors.refinedTeal),
  warmClay('Warm Clay', BaseColors.warmClay),
  mutedModern('Muted Modern', BaseColors.mutedModern),
  contrastDark('Contrast Dark', BaseColors.contrastDark);

  final String displayName;
  final BaseColors colors;

  const ThemePreset(this.displayName, this.colors);
}

/// Provider for managing theme presets.
/// This makes it easy to switch between pre-defined color schemes.
final themePresetProvider = StateProvider<ThemePreset>((ref) {
  return ThemePreset.defaultTheme;
});

/// Extension to make theme switching easier.
extension ThemeExtensions on WidgetRef {
  /// Switch to a different theme preset.
  Future<void> setThemePreset(ThemePreset preset) async {
    read(themePresetProvider.notifier).state = preset;
    await read(baseColorsProvider.notifier).setPreset(preset);
  }

  /// Switch to custom base colors.
  Future<void> setCustomTheme(BaseColors colors) async {
    await read(baseColorsProvider.notifier).setCustom(colors);
  }

  /// Toggle between light and dark mode.
  Future<void> toggleThemeMode() async {
    await read(themeModeProvider.notifier).toggle();
  }

  /// Set a specific theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    await read(themeModeProvider.notifier).setMode(mode);
  }

  /// Toggle CoverFlow view mode (dense/classic).
  Future<void> toggleDenseCoverFlow() async {
    await read(denseCoverFlowProvider.notifier).toggle();
  }

  /// Set CoverFlow view mode.
  Future<void> setDenseCoverFlow(bool useDense) async {
    await read(denseCoverFlowProvider.notifier).setMode(useDense);
  }

  /// Set CoverFlow background style.
  Future<void> setCoverFlowBackgroundStyle(CoverFlowBackgroundStyle style) async {
    await read(coverFlowBackgroundStyleProvider.notifier).setStyle(style);
  }

  /// Toggle floor reflection effect.
  Future<void> toggleFloorReflection() async {
    await read(floorReflectionProvider.notifier).toggle();
  }

  /// Set floor reflection effect.
  Future<void> setFloorReflection(bool enabled) async {
    await read(floorReflectionProvider.notifier).setEnabled(enabled);
  }

  /// Toggle per-card reflections.
  Future<void> toggleCardReflections() async {
    await read(cardReflectionsProvider.notifier).toggle();
  }

  /// Set per-card reflections.
  Future<void> setCardReflections(bool enabled) async {
    await read(cardReflectionsProvider.notifier).setEnabled(enabled);
  }

  /// Toggle blurred album background effect.
  Future<void> toggleBlurredAlbumEffect() async {
    await read(blurredAlbumEffectProvider.notifier).toggle();
  }

  /// Set blurred album background effect.
  Future<void> setBlurredAlbumEffect(bool enabled) async {
    await read(blurredAlbumEffectProvider.notifier).setEnabled(enabled);
  }
}
