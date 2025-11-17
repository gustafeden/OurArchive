import 'package:flutter/material.dart';

/// A button that shows a loading indicator when isLoading is true,
/// commonly used in AppBar actions for save/submit operations
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    this.icon = Icons.check,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}
