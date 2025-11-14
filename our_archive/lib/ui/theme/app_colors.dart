import 'package:flutter/material.dart';

/// Centralized color definitions to replace hardcoded Colors throughout the app
/// This is a ThemeExtension so it works with Material 3 theming
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.photoPlaceholder,
    required this.photoBorder,
    required this.secondaryText,
    required this.tertiaryText,
    required this.infoBackground,
    required this.infoIcon,
    required this.successBackground,
    required this.successIcon,
    required this.warningBackground,
    required this.warningIcon,
    required this.dangerIcon,
    required this.unorganizedBackground,
    required this.unorganizedIcon,
    required this.overlay,
  });

  // Photo picker colors
  final Color photoPlaceholder;
  final Color photoBorder;

  // Text colors (beyond theme defaults)
  final Color secondaryText;
  final Color tertiaryText;

  // Info cards/messages
  final Color infoBackground;
  final Color infoIcon;

  // Success states
  final Color successBackground;
  final Color successIcon;

  // Warning states
  final Color warningBackground;
  final Color warningIcon;

  // Danger/delete actions
  final Color dangerIcon;

  // Unorganized items
  final Color unorganizedBackground;
  final Color unorganizedIcon;

  // Overlays
  final Color overlay;

  // Light theme defaults
  static const AppColors light = AppColors(
    photoPlaceholder: Color(0xFFEEEEEE), // Colors.grey[200]
    photoBorder: Color(0xFFBDBDBD), // Colors.grey[400]
    secondaryText: Color(0xFF757575), // Colors.grey[600]
    tertiaryText: Color(0xFF616161), // Colors.grey[700]
    infoBackground: Color(0xFFE3F2FD), // Colors.blue.shade50
    infoIcon: Color(0xFF1976D2), // Colors.blue[700]
    successBackground: Color(0xFFE8F5E9), // Colors.green.shade50
    successIcon: Color(0xFF388E3C), // Colors.green[700]
    warningBackground: Color(0xFFFFF8E1), // Colors.amber.shade50
    warningIcon: Color(0xFFFFA000), // Colors.amber[700]
    dangerIcon: Color(0xFFD32F2F), // Colors.red[700]
    unorganizedBackground: Color(0xFFFFF3E0), // Colors.orange.shade50
    unorganizedIcon: Colors.orange,
    overlay: Colors.black54,
  );

  @override
  ThemeExtension<AppColors> copyWith({
    Color? photoPlaceholder,
    Color? photoBorder,
    Color? secondaryText,
    Color? tertiaryText,
    Color? infoBackground,
    Color? infoIcon,
    Color? successBackground,
    Color? successIcon,
    Color? warningBackground,
    Color? warningIcon,
    Color? dangerIcon,
    Color? unorganizedBackground,
    Color? unorganizedIcon,
    Color? overlay,
  }) {
    return AppColors(
      photoPlaceholder: photoPlaceholder ?? this.photoPlaceholder,
      photoBorder: photoBorder ?? this.photoBorder,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      infoBackground: infoBackground ?? this.infoBackground,
      infoIcon: infoIcon ?? this.infoIcon,
      successBackground: successBackground ?? this.successBackground,
      successIcon: successIcon ?? this.successIcon,
      warningBackground: warningBackground ?? this.warningBackground,
      warningIcon: warningIcon ?? this.warningIcon,
      dangerIcon: dangerIcon ?? this.dangerIcon,
      unorganizedBackground: unorganizedBackground ?? this.unorganizedBackground,
      unorganizedIcon: unorganizedIcon ?? this.unorganizedIcon,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(
    covariant ThemeExtension<AppColors>? other,
    double t,
  ) {
    if (other is! AppColors) return this;

    return AppColors(
      photoPlaceholder: Color.lerp(photoPlaceholder, other.photoPlaceholder, t)!,
      photoBorder: Color.lerp(photoBorder, other.photoBorder, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      infoBackground: Color.lerp(infoBackground, other.infoBackground, t)!,
      infoIcon: Color.lerp(infoIcon, other.infoIcon, t)!,
      successBackground: Color.lerp(successBackground, other.successBackground, t)!,
      successIcon: Color.lerp(successIcon, other.successIcon, t)!,
      warningBackground: Color.lerp(warningBackground, other.warningBackground, t)!,
      warningIcon: Color.lerp(warningIcon, other.warningIcon, t)!,
      dangerIcon: Color.lerp(dangerIcon, other.dangerIcon, t)!,
      unorganizedBackground: Color.lerp(unorganizedBackground, other.unorganizedBackground, t)!,
      unorganizedIcon: Color.lerp(unorganizedIcon, other.unorganizedIcon, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
    );
  }
}
