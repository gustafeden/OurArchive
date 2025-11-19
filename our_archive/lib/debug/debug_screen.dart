import 'package:flutter/material.dart';
import 'package:faker/faker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/providers.dart';
import '../scripts/migrate_vinyl_to_music.dart' as migration;

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncQueue = ref.read(syncQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Tools'),
        backgroundColor: Colors.red.shade900,
      ),
      body: ListView(
        children: [
          // Sync Queue Stats
          Card(
            child: ListTile(
              title: const Text('Sync Queue Status'),
              subtitle: StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  final stats = syncQueue.getStats();
                  return Text(
                    'High: ${stats['high']} | Normal: ${stats['normal']} | Low: ${stats['low']}',
                  );
                },
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => syncQueue.process(),
              ),
            ),
          ),

          const Divider(),

          // Test Data Generation
          ListTile(
            title: const Text('Generate 50 Test Items'),
            leading: const Icon(Icons.add_box),
            // onTap: () => _generateTestItems(context, ref, 50),
          ),

          ListTile(
            title: const Text('Generate 100 Items'),
            leading: const Icon(Icons.warning, color: Colors.orange),
            // onTap: () => _generateTestItems(context, ref, 100),
          ),

          const Divider(),

          // Network Simulation
          ListTile(
            title: const Text('Simulate Network Error'),
            leading: const Icon(Icons.wifi_off),
            onTap: () => _simulateNetworkError(context),
          ),

          const Divider(),

          // Migration Tools
          ListTile(
            title: const Text('Migrate Vinyl → Music (DRY RUN)'),
            subtitle: const Text('Preview what would be changed'),
            leading: const Icon(Icons.preview, color: Colors.blue),
            onTap: () => _runMigration(context, ref, dryRun: true),
          ),

          ListTile(
            title: const Text('Migrate Vinyl → Music (LIVE)'),
            subtitle: const Text('Actually update the database'),
            leading: const Icon(Icons.play_arrow, color: Colors.red),
            onTap: () => _runMigration(context, ref, dryRun: false),
          ),

          const Divider(),

          // Info
          // Card(
          //   color: Colors.blue.shade50,
          //   child: const Padding(
          //     padding: EdgeInsets.all(16),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text(
          //           'Debug Mode',
          //           style: TextStyle(
          //             fontWeight: FontWeight.bold,
          //             fontSize: 16,
          //           ),
          //         ),
          //         SizedBox(height: 8),
          //         Text(
          //           'This screen is only visible in debug builds. '
          //           'Use it to test offline sync, generate test data, '
          //           'and monitor the sync queue.',
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Future<void> _generateTestItems(BuildContext context, WidgetRef ref, int count) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a household first')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Generating $count items...'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('This may take a few moments'),
          ],
        ),
      ),
    );

    try {
      final faker = Faker();
      final itemRepo = ref.read(itemRepositoryProvider);
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId!;

      final types = ['tool', 'pantry', 'camera', 'book', 'electronics'];
      final locations = ['Garage', 'Kitchen', 'Living Room', 'Bedroom', 'Office'];

      for (int i = 0; i < count; i++) {
        final itemData = {
          'title': faker.lorem.words(3).join(' '),
          'type': types[i % types.length],
          'location': locations[i % locations.length],
          'tags': [
            faker.lorem.word(),
            faker.color.color(),
          ],
          'quantity': faker.randomGenerator.integer(10, min: 1),
          'archived': false,
          'sortOrder': 0,
        };

        await itemRepo.addItem(
          householdId: householdId,
          userId: userId,
          itemData: itemData,
        );
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated $count test items')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _simulateNetworkError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Network error simulated - check sync queue'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _runMigration(BuildContext context, WidgetRef ref, {required bool dryRun}) async {
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUserId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Not signed in')),
      );
      return;
    }

    // Confirm action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dryRun ? 'Dry Run Migration' : 'LIVE Migration'),
        content: Text(
          dryRun
              ? 'This will preview what would be changed in YOUR households without making any updates.'
              : 'WARNING: This will update all items with type="vinyl" to type="music" in YOUR households. This cannot be easily undone.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dryRun ? Colors.blue : Colors.red,
            ),
            child: Text(dryRun ? 'Preview' : 'Run Migration'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    final logs = <String>[];

    // Need to capture setState from StatefulBuilder
    void Function(void Function())? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          // Capture setState so we can call it from onProgress
          dialogSetState = setState;

          return AlertDialog(
            title: Text(dryRun ? 'Migration Preview' : 'Running Migration'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          return Text(
                            logs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.black,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );

    try {
      await migration.migrateVinylToMusic(
        firestore: FirebaseFirestore.instance,
        userId: userId,
        dryRun: dryRun,
        onProgress: (message) {
          logs.add(message);
          // Use the captured setState to rebuild the dialog
          dialogSetState?.call(() {});
        },
      );

      // Don't close dialog - let user review logs
      // Just show a snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dryRun ? '✅ Preview complete - review logs above' : '✅ Migration complete!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog

        // Show error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Migration Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('An error occurred during migration:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e.toString(),
                    style: const TextStyle(fontFamily: 'monospace', color: Colors.black),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }
}
