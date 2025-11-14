import 'package:flutter/material.dart';

/// Reusable button with loading state
/// Eliminates 10+ duplicate loading button patterns across screens
class AppLoadingButton extends StatelessWidget {
  const AppLoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.isLoading,
    this.icon,
    this.isPrimary = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final IconData? icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final buttonIcon = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : (icon != null ? Icon(icon) : null);

    final buttonLabel = Text(isLoading ? 'Saving...' : label);

    if (isPrimary) {
      return FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: buttonIcon ?? const SizedBox.shrink(),
        label: buttonLabel,
      );
    } else {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: buttonIcon ?? const SizedBox.shrink(),
        label: buttonLabel,
      );
    }
  }
}

/// Convenience constructor for icon-less button
class AppLoadingButtonText extends StatelessWidget {
  const AppLoadingButtonText({
    super.key,
    required this.onPressed,
    required this.label,
    required this.isLoading,
    this.isPrimary = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = Text(isLoading ? 'Loading...' : label);

    if (isPrimary) {
      return FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : buttonLabel,
      );
    } else {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : buttonLabel,
      );
    }
  }
}
