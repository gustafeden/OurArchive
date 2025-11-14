import 'package:flutter/material.dart';
import 'package:our_archive/ui/screens/add_book_flow_screen.dart';
import 'package:our_archive/ui/screens/add_vinyl_flow_screen.dart';
import 'package:our_archive/ui/screens/add_game_screen.dart';
import 'package:our_archive/ui/screens/add_item_screen.dart';
import 'package:our_archive/ui/screens/book_scan_screen.dart';
import 'package:our_archive/ui/screens/vinyl_scan_screen.dart';

class ItemTypeSelectionScreen extends StatelessWidget {
  final String householdId;

  const ItemTypeSelectionScreen({
    Key? key,
    required this.householdId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
      ),
      body: SafeArea(
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
                              initialMode: BookScanMode.camera,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
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
                              initialMode: VinylScanMode.camera,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
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
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                  children: [
                    _ItemTypeCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Book',
                      subtitle: 'Scan, search, or add manually',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddBookFlowScreen(
                              householdId: householdId,
                            ),
                          ),
                        );
                      },
                    ),
                    _ItemTypeCard(
                      icon: Icons.library_music_rounded,
                      title: 'Music',
                      subtitle: 'Vinyl, CD, cassette, or other formats',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddVinylFlowScreen(
                              householdId: householdId,
                            ),
                          ),
                        );
                      },
                    ),
                    _ItemTypeCard(
                      icon: Icons.videogame_asset_rounded,
                      title: 'Game',
                      subtitle: 'Add your video game collection',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddGameScreen(
                              householdId: householdId,
                            ),
                          ),
                        );
                      },
                    ),
                    _ItemTypeCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'General Item',
                      subtitle: 'Tools, electronics, pantry items',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddItemScreen(
                              householdId: householdId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
