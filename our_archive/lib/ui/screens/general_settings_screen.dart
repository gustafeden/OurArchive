import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';

/// General app settings screen for non-theme related preferences.
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useDenseCoverFlow = ref.watch(denseCoverFlowProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('General Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // CoverFlow Display Section
          _buildSectionHeader('CoverFlow Display'),
          const SizedBox(height: 8),
          _CoverFlowModeSelector(useDenseMode: useDenseCoverFlow),
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
                          ? colorScheme.onPrimaryContainer.withOpacity(0.8)
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
