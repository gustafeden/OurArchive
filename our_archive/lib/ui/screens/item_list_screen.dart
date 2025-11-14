import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/item.dart';
import 'add_item_screen.dart';
import 'container_screen.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  final Household household;

  const ItemListScreen({super.key, required this.household});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  @override
  void initState() {
    super.initState();
    // Set the current household when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentHouseholdIdProvider.notifier).state = widget.household.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(householdItemsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.currentUser!;
    final isOwner = widget.household.isOwner(currentUser.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.household.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2),
            tooltip: 'Organize',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContainerScreen(
                    householdId: widget.household.id,
                    householdName: widget.household.name,
                  ),
                ),
              );
            },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Show household code',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Household Code'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Share this code with family members:'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.household.code,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: widget.household.code),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Code copied!')),
                                  );
                                },
                              ),
                            ],
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
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Items list
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
              data: (items) {
                // Apply search filter
                final filteredItems = searchQuery.isEmpty
                    ? items
                    : items.where((item) =>
                        item.searchText.contains(searchQuery.toLowerCase())).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty ? 'No items found' : 'No items yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Try a different search term'
                              : 'Tap + to add your first item',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _ItemCard(item: item, household: widget.household);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemScreen(household: widget.household),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final Item item;
  final Household household;

  const _ItemCard({required this.item, required this.household});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: item.photoThumbPath != null
            ? CircleAvatar(
                backgroundColor: Colors.grey[300],
                child: const Icon(Icons.image),
              )
            : CircleAvatar(
                child: Text(item.type[0].toUpperCase()),
              ),
        title: Text(item.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.type),
            if (item.location.isNotEmpty) Text('📍 ${item.location}'),
            if (item.quantity > 1) Text('Qty: ${item.quantity}'),
          ],
        ),
        trailing: item.syncStatus != SyncStatus.synced
            ? const Icon(Icons.sync, size: 16)
            : null,
        onTap: () {
          // TODO: Navigate to item detail screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item details coming soon'),
            ),
          );
        },
      ),
    );
  }
}
