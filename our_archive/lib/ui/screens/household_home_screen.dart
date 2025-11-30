import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../data/models/household.dart';
import '../../providers/providers.dart';
import '../widgets/liquid_glass_scaffold.dart';
import 'item_list_screen.dart';
import 'container_screen.dart';
import 'book_grid_browser.dart';
import 'coverflow_music_browser.dart';

/// The main household home screen with liquid glass bottom navigation
class HouseholdHomeScreen extends ConsumerStatefulWidget {
  final Household household;
  final int initialTabIndex;

  const HouseholdHomeScreen({
    super.key,
    required this.household,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<HouseholdHomeScreen> createState() => _HouseholdHomeScreenState();
}

class _HouseholdHomeScreenState extends ConsumerState<HouseholdHomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    // Set the current household when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentHouseholdIdProvider.notifier).state = widget.household.id;
    });
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
          label: 'Items',
          icon: Ionicons.list_outline,
          activeIcon: Ionicons.list,
        ),
        LiquidGlassTab(
          label: 'Organize',
          icon: Ionicons.cube_outline,
          activeIcon: Ionicons.cube,
        ),
        LiquidGlassTab(
          label: 'Books',
          icon: Ionicons.book_outline,
          activeIcon: Ionicons.book,
        ),
        LiquidGlassTab(
          label: 'Music',
          icon: Ionicons.disc_outline,
          activeIcon: Ionicons.disc,
        ),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Items tab
          ItemListScreen(
            household: widget.household,
          ),
          // Organize tab
          ContainerScreen(
            householdId: widget.household.id,
            householdName: widget.household.name,
          ),
          // Books tab
          BookGridBrowser(
            householdId: widget.household.id,
          ),
          // Music tab
          CoverFlowMusicBrowser(
            householdId: widget.household.id,
          ),
        ],
      ),
    );
  }
}
