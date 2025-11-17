import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:our_archive/ui/screens/add_book_flow_screen.dart';
import 'package:our_archive/ui/screens/add_vinyl_flow_screen.dart';
import 'package:our_archive/ui/screens/add_game_screen.dart';
import 'package:our_archive/ui/screens/add_item_screen.dart';
import 'package:our_archive/ui/screens/book_scan_screen.dart';
import 'package:our_archive/ui/screens/vinyl_scan_screen.dart';
import 'package:our_archive/ui/screens/common/scan_modes.dart';
import '../../providers/providers.dart';
import '../../data/models/item_type.dart';
import '../../utils/icon_helper.dart';

class ItemTypeSelectionScreen extends ConsumerWidget {
  final String householdId;
  final String? preSelectedContainerId;

  const ItemTypeSelectionScreen({
    Key? key,
    required this.householdId,
    this.preSelectedContainerId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemTypesAsync = ref.watch(itemTypesProvider(householdId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
      ),
      body: itemTypesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error loading types: $error')),
        data: (itemTypes) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                'What would you like to add?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the type of item to get started',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookScanScreen(
                              householdId: householdId,
                              initialMode: ScanMode.camera,
                              preSelectedContainerId: preSelectedContainerId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Ionicons.qr_code_outline, size: 20),
                      label: const Text('Scan Book'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VinylScanScreen(
                              householdId: householdId,
                              initialMode: ScanMode.camera,
                              preSelectedContainerId: preSelectedContainerId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Ionicons.qr_code_outline, size: 20),
                      label: const Text('Scan Music'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: BorderSide(color: Colors.purple.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: itemTypes.where((type) => type.hasSpecializedForm || type.name == 'general').length,
                    itemBuilder: (context, index) {
                      final filteredTypes = itemTypes.where((type) => type.hasSpecializedForm || type.name == 'general').toList();
                      final type = filteredTypes[index];
                      return _buildItemTypeCard(context, type);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemTypeCard(BuildContext context, ItemType type) {
    // Define colors for different types
    final color = _getColorForType(type);
    final subtitle = _getSubtitleForType(type);

    return _ItemTypeCard(
      icon: IconHelper.getIconData(type.icon),
      title: type.displayName,
      subtitle: subtitle,
      color: color,
      onTap: () {
        // Route based on whether type has specialized form
        if (type.hasSpecializedForm) {
          switch (type.name) {
            case 'book':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddBookFlowScreen(
                    householdId: householdId,
                    preSelectedContainerId: preSelectedContainerId,
                  ),
                ),
              );
              break;
            case 'vinyl':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddVinylFlowScreen(
                    householdId: householdId,
                    preSelectedContainerId: preSelectedContainerId,
                  ),
                ),
              );
              break;
            case 'game':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddGameScreen(
                    householdId: householdId,
                    preSelectedContainerId: preSelectedContainerId,
                  ),
                ),
              );
              break;
          }
        } else {
          // Generic item form
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemScreen(
                householdId: householdId,
                preSelectedContainerId: preSelectedContainerId,
              ),
            ),
          );
        }
      },
    );
  }

  Color _getColorForType(ItemType type) {
    // Use predefined colors for default types, or generate based on name hash for custom
    if (type.isDefault) {
      switch (type.name) {
        case 'book':
          return Colors.blue;
        case 'vinyl':
          return Colors.purple;
        case 'game':
          return Colors.green;
        case 'general':
          return Colors.orange;
        default:
          return Colors.teal;
      }
    }
    // For custom types, generate a color based on hash
    final hash = type.name.hashCode;
    return Color((hash & 0xFFFFFF) | 0xFF000000).withOpacity(0.8);
  }

  String _getSubtitleForType(ItemType type) {
    if (type.isDefault) {
      switch (type.name) {
        case 'book':
          return 'Scan, search, or add manually';
        case 'vinyl':
          return 'Vinyl, CD, cassette, or other formats';
        case 'game':
          return 'Add your video game collection';
        case 'general':
          return 'Tools, electronics, pantry items';
        default:
          return 'Add to your collection';
      }
    }
    return 'Add to your collection';
  }
}

class _ItemTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ItemTypeCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
