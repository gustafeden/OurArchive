import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Main app theme configuration
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      extensions: const [
        AppColors.light,
      ],
    );
  }

  // Easy access to theme extensions
  static AppColors colorsOf(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? AppColors.light;
  }
}
