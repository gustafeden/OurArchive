import 'package:flutter/material.dart';
import 'package:our_archive/ui/screens/vinyl_scan_screen.dart';
import 'package:our_archive/ui/screens/add_vinyl_screen.dart';

class AddVinylFlowScreen extends StatelessWidget {
  final String householdId;

  const AddVinylFlowScreen({
    Key? key,
    required this.householdId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vinyl Record'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How would you like to add your vinyl?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the method that works best for you',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    _EntryMethodCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Scan Barcode',
                      description: 'Scan the barcode to find on Discogs',
                      color: Colors.purple,
                      onTap: () {
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
                    ),
                    const SizedBox(height: 16),
                    _EntryMethodCard(
                      icon: Icons.search_rounded,
                      title: 'Search Discogs',
                      description: 'Search by artist, album, or catalog number',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VinylScanScreen(
                              householdId: householdId,
                              initialMode: VinylScanMode.textSearch,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _EntryMethodCard(
                      icon: Icons.edit_rounded,
                      title: 'Manual Entry',
                      description: 'Enter vinyl details manually',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddVinylScreen(
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

class _EntryMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _EntryMethodCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
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
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
