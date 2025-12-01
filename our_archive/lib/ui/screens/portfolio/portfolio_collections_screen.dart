import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/portfolio_providers.dart';
import '../../../data/models/portfolio_collection.dart';
import '../../services/ui_service.dart';
import 'portfolio_collection_detail_screen.dart';

class PortfolioCollectionsScreen extends ConsumerStatefulWidget {
  const PortfolioCollectionsScreen({super.key});

  @override
  ConsumerState<PortfolioCollectionsScreen> createState() =>
      _PortfolioCollectionsScreenState();
}

class _PortfolioCollectionsScreenState
    extends ConsumerState<PortfolioCollectionsScreen> {
  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(portfolioCollectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Ionicons.add_outline),
            onPressed: () => _showCreateCollectionDialog(context),
          ),
        ],
      ),
      body: collectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Ionicons.alert_circle_outline,
                  size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(portfolioCollectionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (collections) {
          if (collections.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Ionicons.images_outline,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No collections yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first collection to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCreateCollectionDialog(context),
                    icon: const Icon(Ionicons.add_outline),
                    label: const Text('Create Collection'),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: collections.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(collections, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final collection = collections[index];
              return _CollectionCard(
                key: ValueKey(collection.id),
                collection: collection,
                onTap: () => _openCollection(context, collection),
                onEdit: () => _showEditCollectionDialog(context, collection),
                onDelete: () => _showDeleteConfirmation(context, collection),
                onToggleVisibility: () => _toggleVisibility(collection),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateCollectionDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            hintText: 'e.g., Fuji 18-55',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) {
                UiService.showWarning('Please enter a name');
                return;
              }

              Navigator.pop(context);

              try {
                final repository = ref.read(portfolioRepositoryProvider);
                await repository.createCollection(title);
                UiService.showSuccess('Collection created');
              } catch (e) {
                UiService.showError('Error: $e');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditCollectionDialog(
      BuildContext context, PortfolioCollection collection) {
    final titleController = TextEditingController(text: collection.title);
    final descController =
        TextEditingController(text: collection.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                UiService.showWarning('Please enter a name');
                return;
              }

              Navigator.pop(context);

              try {
                final repository = ref.read(portfolioRepositoryProvider);
                final updated = collection.copyWith(
                  title: title,
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                );
                await repository.updateCollection(updated);
                UiService.showSuccess('Collection updated');
              } catch (e) {
                UiService.showError('Error: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, PortfolioCollection collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text(
          'This will permanently delete "${collection.title}" and all photos in it. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final repository = ref.read(portfolioRepositoryProvider);
                await repository.deleteCollection(collection.id);
                UiService.showSuccess('Collection deleted');
              } catch (e) {
                UiService.showError('Error: $e');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openCollection(BuildContext context, PortfolioCollection collection) {
    ref.read(selectedPortfolioCollectionProvider.notifier).state = collection;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PortfolioCollectionDetailScreen(collection: collection),
      ),
    );
  }

  Future<void> _toggleVisibility(PortfolioCollection collection) async {
    try {
      final repository = ref.read(portfolioRepositoryProvider);
      final updated = collection.copyWith(visible: !collection.visible);
      await repository.updateCollection(updated);
      UiService.showSuccess(
          updated.visible ? 'Collection visible' : 'Collection hidden');
    } catch (e) {
      UiService.showError('Error: $e');
    }
  }

  Future<void> _onReorder(
      List<PortfolioCollection> collections, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final reordered = List<PortfolioCollection>.from(collections);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    try {
      final repository = ref.read(portfolioRepositoryProvider);
      await repository.reorderCollections(reordered);
    } catch (e) {
      UiService.showError('Error reordering: $e');
    }
  }
}

class _CollectionCard extends StatelessWidget {
  final PortfolioCollection collection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleVisibility;

  const _CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Cover image
            SizedBox(
              width: 100,
              height: 100,
              child: collection.cover != null
                  ? CachedNetworkImage(
                      imageUrl: collection.cover!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Ionicons.image_outline),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(Ionicons.images_outline,
                          size: 32, color: Colors.grey[400]),
                    ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            collection.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!collection.visible)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Hidden',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (collection.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        collection.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'slug: ${collection.slug}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Ionicons.ellipsis_vertical_outline),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'visibility':
                    onToggleVisibility();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Ionicons.pencil_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'visibility',
                  child: Row(
                    children: [
                      Icon(
                        collection.visible
                            ? Ionicons.eye_off_outline
                            : Ionicons.eye_outline,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(collection.visible ? 'Hide' : 'Show'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Ionicons.trash_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
