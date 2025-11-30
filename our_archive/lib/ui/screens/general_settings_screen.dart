import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../widgets/coverflow/coverflow_background.dart';
import 'theme_settings_screen.dart';

/// General app settings screen for non-theme related preferences.
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useDenseCoverFlow = ref.watch(denseCoverFlowProvider);
    final floorReflectionEnabled = ref.watch(floorReflectionProvider);
    final cardReflectionsEnabled = ref.watch(cardReflectionsProvider);
    final blurredAlbumEnabled = ref.watch(blurredAlbumEffectProvider);
    final backgroundStyle = ref.watch(coverFlowBackgroundStyleProvider);

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('General Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
        children: [
          // Theme & Appearance Section
          _buildSectionHeader('Appearance'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Ionicons.color_palette_outline),
              title: const Text('Theme & Colors'),
              subtitle: const Text('Color themes, light/dark mode'),
              trailing: const Icon(Ionicons.chevron_forward_outline),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemeSettingsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // CoverFlow Display Section
          _buildSectionHeader('CoverFlow Display'),
          const SizedBox(height: 8),
          _CoverFlowModeSelector(useDenseMode: useDenseCoverFlow),
          const SizedBox(height: 24),

          // CoverFlow Background Section
          _buildSectionHeader('CoverFlow Background'),
          const SizedBox(height: 8),
          _CoverFlowBackgroundSelector(currentStyle: backgroundStyle),
          const SizedBox(height: 24),

          // CoverFlow Effects Section
          _buildSectionHeader('CoverFlow Effects'),
          const SizedBox(height: 8),
          _CoverFlowEffectsSelector(
            floorReflectionEnabled: floorReflectionEnabled,
            cardReflectionsEnabled: cardReflectionsEnabled,
            blurredAlbumEnabled: blurredAlbumEnabled,
          ),
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

/// Widget for selecting CoverFlow view mode (dense/classic).
class _CoverFlowModeSelector extends ConsumerWidget {
  final bool useDenseMode;

  const _CoverFlowModeSelector({required this.useDenseMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _CoverFlowModeOption(
              icon: Ionicons.albums_outline,
              label: 'Dense View',
              description: 'More albums visible, overlapping (landscape only)',
              isSelected: useDenseMode,
              onTap: () => ref.setDenseCoverFlow(true),
            ),
            const SizedBox(height: 8),
            _CoverFlowModeOption(
              icon: Ionicons.disc_outline,
              label: 'Classic View',
              description: 'Traditional spacing, fewer albums (landscape only)',
              isSelected: !useDenseMode,
              onTap: () => ref.setDenseCoverFlow(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual CoverFlow mode option button.
class _CoverFlowModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _CoverFlowModeOption({
    required this.icon,
    required this.label,
    required this.description,
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
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Ionicons.checkmark_circle,
                color: colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget for selecting CoverFlow effects with card-style selection.
class _CoverFlowEffectsSelector extends ConsumerWidget {
  final bool floorReflectionEnabled;
  final bool cardReflectionsEnabled;
  final bool blurredAlbumEnabled;

  const _CoverFlowEffectsSelector({
    required this.floorReflectionEnabled,
    required this.cardReflectionsEnabled,
    required this.blurredAlbumEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _EffectOption(
              icon: Ionicons.water_outline,
              label: 'Floor Reflection',
              description: 'Classic Apple Cover Flow style reflection beneath albums',
              isSelected: floorReflectionEnabled,
              onTap: () async {
                // Only allow selection if not already selected (prevent deselecting all)
                if (!floorReflectionEnabled) {
                  await ref.setFloorReflection(true);
                  await ref.setCardReflections(false);
                  await ref.setBlurredAlbumEffect(false);
                }
              },
            ),
            const SizedBox(height: 8),
            _EffectOption(
              icon: Ionicons.albums_outline,
              label: 'Album Card Reflections',
              description: 'Individual reflections beneath each album cover',
              isSelected: cardReflectionsEnabled,
              onTap: () async {
                // Only allow selection if not already selected (prevent deselecting all)
                if (!cardReflectionsEnabled) {
                  await ref.setCardReflections(true);
                  await ref.setFloorReflection(false);
                  await ref.setBlurredAlbumEffect(false);
                }
              },
            ),
            const SizedBox(height: 8),
            _EffectOption(
              icon: Ionicons.color_palette_outline,
              label: 'Blurred Album Background',
              description: 'Dynamic blurred background based on album art',
              isSelected: blurredAlbumEnabled,
              onTap: () async {
                // Only allow selection if not already selected (prevent deselecting all)
                if (!blurredAlbumEnabled) {
                  await ref.setBlurredAlbumEffect(true);
                  await ref.setFloorReflection(false);
                  await ref.setCardReflections(false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual effect option button with card-style selection.
class _EffectOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _EffectOption({
    required this.icon,
    required this.label,
    required this.description,
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
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Ionicons.checkmark_circle,
                color: colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget for selecting CoverFlow background style.
class _CoverFlowBackgroundSelector extends ConsumerWidget {
  final CoverFlowBackgroundStyle currentStyle;

  const _CoverFlowBackgroundSelector({required this.currentStyle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: CoverFlowBackgroundStyle.values.map((style) {
            final isLast = style == CoverFlowBackgroundStyle.values.last;
            return Column(
              children: [
                _BackgroundStyleOption(
                  style: style,
                  isSelected: currentStyle == style,
                  onTap: () => ref.setCoverFlowBackgroundStyle(style),
                ),
                if (!isLast) const SizedBox(height: 8),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Individual background style option button.
class _BackgroundStyleOption extends StatelessWidget {
  final CoverFlowBackgroundStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  const _BackgroundStyleOption({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  IconData _getIconForStyle(CoverFlowBackgroundStyle style) {
    return Ionicons.radio_button_off_outline;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Icon(
              _getIconForStyle(style),
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.displayName,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    style.description,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Ionicons.checkmark_circle,
                color: colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
