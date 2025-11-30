import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class UiService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    _showSnackBar(message, Colors.green, Ionicons.checkmark_circle_outline);
  }

  static void showError(String message) {
    _showSnackBar(message, Colors.red, Ionicons.alert_circle_outline);
  }

  static void showWarning(String message) {
    _showSnackBar(message, Colors.orange, Ionicons.warning_outline);
  }

  static void showInfo(String message) {
    _showSnackBar(message, null, Ionicons.information_circle_outline);
  }

  static void showWithUndo({
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: onUndo,
        ),
      ),
    );
  }

  static void _showSnackBar(String message, Color? backgroundColor, IconData icon) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
