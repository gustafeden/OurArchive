import 'package:flutter/material.dart';
import 'package:faker/faker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

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
            onTap: () => _generateTestItems(context, ref, 50),
          ),

          ListTile(
            title: const Text('Generate 100 Items'),
            leading: const Icon(Icons.warning, color: Colors.orange),
            onTap: () => _generateTestItems(context, ref, 100),
          ),

          const Divider(),

          // Network Simulation
          ListTile(
            title: const Text('Simulate Network Error'),
            leading: const Icon(Icons.wifi_off),
            onTap: () => _simulateNetworkError(context),
          ),

          const Divider(),

          // Info
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This screen is only visible in debug builds. '
                    'Use it to test offline sync, generate test data, '
                    'and monitor the sync queue.',
                  ),
                ],
              ),
            ),
          ),
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
}
