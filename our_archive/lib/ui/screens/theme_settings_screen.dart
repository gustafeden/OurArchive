import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';

/// Theme settings screen where users can preview and switch themes.
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Mode Section
          _buildSectionHeader('Theme Mode'),
          const SizedBox(height: 8),
          _ThemeModeSelector(currentMode: currentThemeMode),
          const SizedBox(height: 32),

          // Theme Presets Section
          _buildSectionHeader('Color Themes'),
          const SizedBox(height: 8),
          const Text(
            'Choose from our curated color palettes',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _ThemePresetGrid(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// Widget for selecting theme mode (light/dark/system).
class _ThemeModeSelector extends ConsumerWidget {
  final ThemeMode currentMode;

  const _ThemeModeSelector({required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: _ThemeModeOption(
                mode: ThemeMode.light,
                icon: Ionicons.sunny_outline,
                label: 'Light',
                isSelected: currentMode == ThemeMode.light,
                onTap: () => ref.setThemeMode(ThemeMode.light),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeModeOption(
                mode: ThemeMode.dark,
                icon: Ionicons.moon_outline,
                label: 'Dark',
                isSelected: currentMode == ThemeMode.dark,
                onTap: () => ref.setThemeMode(ThemeMode.dark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeModeOption(
                mode: ThemeMode.system,
                icon: Ionicons.contrast_outline,
                label: 'System',
                isSelected: currentMode == ThemeMode.system,
                onTap: () => ref.setThemeMode(ThemeMode.system),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual theme mode option button.
class _ThemeModeOption extends StatelessWidget {
  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.mode,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid of theme preset cards.
class _ThemePresetGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBaseColors = ref.watch(baseColorsProvider);

    return Column(
      children: ThemePreset.values.map((preset) {
        final isSelected = currentBaseColors == preset.colors;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ThemePresetCard(
            preset: preset,
            isSelected: isSelected,
            onTap: () => ref.setThemePreset(preset),
          ),
        );
      }).toList(),
    );
  }
}

/// Individual theme preset card with color preview.
class _ThemePresetCard extends StatelessWidget {
  final ThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color palette preview
            Row(
              children: [
                _ColorSwatch(color: preset.colors.primary, flex: 3),
                _ColorSwatch(color: preset.colors.secondary, flex: 2),
                _ColorSwatch(color: preset.colors.tertiary, flex: 2),
                _ColorSwatch(color: preset.colors.neutral, flex: 2),
                _ColorSwatch(color: preset.colors.accent, flex: 1),
              ],
            ),

            // Theme name and selection indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getThemeDescription(preset),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (isSelected)
                    Icon(
                      Ionicons.checkmark_circle_outline,
                      color: colorScheme.primary,
                      size: 32,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeDescription(ThemePreset preset) {
    switch (preset) {
      case ThemePreset.defaultTheme:
        return 'Fresh teal and cyan tones';
      case ThemePreset.palette4:
        return 'Earthy olive and sage palette';
      case ThemePreset.darkTheme:
        return 'Dark mode optimized colors';
      case ThemePreset.dustyRose:
        return 'Warm browns with dusty rose accents';
      case ThemePreset.nature:
        return 'Earthy sage and forest greens';
      case ThemePreset.ocean:
        return 'Deep ocean teal with sage tones';
      case ThemePreset.coastal:
        return 'Soft sea greens and coastal blues';
      case ThemePreset.sunset:
        return 'Vibrant coral and warm oranges';
      case ThemePreset.forest:
        return 'Rich natural forest greens';
      case ThemePreset.berry:
        return 'Bold purples and vibrant pinks';
      case ThemePreset.refinedTeal:
        return 'Professional dark teal with orange highlights';
      case ThemePreset.warmClay:
        return 'Earthy clay browns and terracotta';
      case ThemePreset.mutedModern:
        return 'Sophisticated muted teal and gray';
      case ThemePreset.contrastDark:
        return 'High contrast emerald and turquoise';
    }
  }
}

/// Individual color swatch in the preview.
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final int flex;

  const _ColorSwatch({
    required this.color,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color,
        ),
      ),
    );
  }
}
