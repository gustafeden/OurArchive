import 'package:flutter/material.dart';

/// Standardized year input field with consistent styling
class YearField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool required;

  const YearField({
    super.key,
    required this.controller,
    this.labelText = 'Year',
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      maxLength: 4,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      validator: required
          ? (v) => v?.trim().isEmpty ?? true ? 'Year is required' : null
          : null,
    );
  }
}
