import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../widgets/liquid_glass_scaffold.dart';
import 'household_list_screen.dart';
import 'profile_screen.dart';
import 'general_settings_screen.dart';

/// The main home screen with liquid glass bottom navigation
/// Shows tabs for Households, Profile, and Settings
class MainHomeScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MainHomeScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends ConsumerState<MainHomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScaffold(
      selectedIndex: _currentIndex,
      onTabSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      tabs: const [
        LiquidGlassTab(
          label: 'Home',
          icon: Ionicons.home_outline,
          activeIcon: Ionicons.home,
        ),
        LiquidGlassTab(
          label: 'Profile',
          icon: Ionicons.person_outline,
          activeIcon: Ionicons.person,
        ),
        LiquidGlassTab(
          label: 'Settings',
          icon: Ionicons.settings_outline,
          activeIcon: Ionicons.settings,
        ),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          // Home tab - Household list (without its own app bar profile button)
          _HouseholdListContent(),
          // Profile tab
          ProfileScreen(),
          // Settings tab
          GeneralSettingsScreen(),
        ],
      ),
    );
  }
}

/// Household list content without the profile button in app bar
/// (since profile is now a separate tab)
class _HouseholdListContent extends ConsumerWidget {
  const _HouseholdListContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Just render the HouseholdListScreen as-is
    // It has its own Scaffold with AppBar
    return const HouseholdListScreen();
  }
}
