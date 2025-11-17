import 'package:flutter/material.dart';

/// A reusable manual entry view for ISBN/barcode input.
///
/// Provides a consistent form layout with:
/// - Text field for manual code entry
/// - Submit button with loading state
/// - Customizable labels and keyboard type
///
/// Usage:
/// ```dart
/// ManualEntryView(
///   controller: _manualIsbnController,
///   labelText: 'ISBN',
///   hintText: 'Enter ISBN or barcode',
///   buttonText: 'Look Up Book',
///   isProcessing: _isProcessing,
///   onSubmit: _handleManualEntry,
/// )
/// ```
class ManualEntryView extends StatelessWidget {
  /// Controller for the text field
  final TextEditingController controller;

  /// Label text for the text field
  final String labelText;

  /// Hint text for the text field
  final String hintText;

  /// Text for the submit button
  final String buttonText;

  /// Whether the lookup is currently processing
  final bool isProcessing;

  /// Callback when submit button is pressed or text is submitted
  final VoidCallback onSubmit;

  /// Keyboard type for the text field (defaults to number)
  final TextInputType keyboardType;

  const ManualEntryView({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.buttonText,
    required this.isProcessing,
    required this.onSubmit,
    this.keyboardType = TextInputType.number,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
            keyboardType: keyboardType,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: isProcessing ? null : onSubmit,
            child: isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(buttonText),
          ),
        ],
      ),
    );
  }
}
