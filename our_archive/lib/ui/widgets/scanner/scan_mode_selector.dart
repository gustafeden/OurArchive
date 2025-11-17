import 'package:flutter/material.dart';
import '../../screens/common/scan_modes.dart';

/// Reusable widget for switching between scan modes
///
/// Provides a PopupMenuButton that displays all available scan modes
/// and allows the user to select one.
///
/// Usage:
/// ```dart
/// ScanModeSelector(
///   currentMode: _currentMode,
///   availableModes: [
///     ScanMode.camera,
///     ScanMode.manual,
///     ScanMode.textSearch,
///   ],
///   onModeSelected: (mode) {
///     setState(() => _currentMode = mode);
///   },
/// )
/// ```
class ScanModeSelector extends StatelessWidget {
  /// Currently selected scan mode
  final ScanMode currentMode;

  /// List of scan modes available for selection
  final List<ScanMode> availableModes;

  /// Callback when a scan mode is selected
  final ValueChanged<ScanMode> onModeSelected;

  /// Optional tooltip text (defaults to "Switch Mode")
  final String tooltip;

  const ScanModeSelector({
    super.key,
    required this.currentMode,
    required this.availableModes,
    required this.onModeSelected,
    this.tooltip = 'Switch Mode',
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ScanMode>(
      icon: Icon(currentMode.icon),
      tooltip: tooltip,
      onSelected: onModeSelected,
      itemBuilder: (context) => availableModes
          .map(
            (mode) => PopupMenuItem(
              value: mode,
              child: ListTile(
                leading: Icon(mode.icon),
                title: Text(mode.label),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          )
          .toList(),
    );
  }
}
