import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';

/// A reusable widget for displaying empty states with consistent styling.
///
/// Shows a large icon, title, and optional subtitle message to indicate
/// when a list or collection has no items to display.
///
/// Usage:
/// ```dart
/// if (items.isEmpty) {
///   return EmptyStateWidget(
///     icon: Ionicons.mail_outline,
///     title: 'No items yet',
///     subtitle: 'Tap + to add your first item',
///   );
/// }
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// The icon to display (defaults to inbox)
  final IconData icon;

  /// The main title/message
  final String title;

  /// Optional subtitle with additional context or action hint
  final String? subtitle;

  /// Size of the icon (defaults to 80)
  final double iconSize;

  /// Color of the icon (defaults to grey[400])
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    this.icon = Ionicons.mail_outline,
    required this.title,
    this.subtitle,
    this.iconSize = 80,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
