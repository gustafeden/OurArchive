import 'package:flutter/material.dart';

/// Standardized notes/description multiline text field
class NotesField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final int maxLines;
  final bool required;

  const NotesField({
    super.key,
    required this.controller,
    this.labelText = 'Notes (optional)',
    this.maxLines = 4,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.note),
        alignLabelWithHint: true,
      ),
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      validator: required
          ? (v) => v?.trim().isEmpty ?? true ? 'Notes required' : null
          : null,
    );
  }
}
