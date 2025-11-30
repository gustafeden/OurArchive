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
        hintText: 'YYYY',
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      maxLength: 4,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      validator: (value) {
        if (value == null || value.isEmpty) {
          if (required) {
            return 'Year is required';
          }
          return null; // Optional
        }
        final year = int.tryParse(value);
        if (year == null) {
          return 'Enter a valid year';
        }
        if (year < 1800 || year > DateTime.now().year + 1) {
          return 'Year must be between 1800 and ${DateTime.now().year + 1}';
        }
        return null;
      },
    );
  }
}
