import 'package:flutter/material.dart';

/// Reusable text field with consistent styling
/// Eliminates repeated TextFormField configurations across add-item screens
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.validator,
    this.prefixIcon,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final bool enabled;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
