import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/item.dart';
import '../../data/models/household.dart';
import '../../data/models/container.dart' as model;
import '../../providers/providers.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final Item item;
  final Household household;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.household,
  });

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _typeController;
  late TextEditingController _quantityController;
  late TextEditingController _barcodeController;
  late List<String> _tags;
  late String? _selectedContainerId;

  bool _isEditMode = false;
  bool _isLoading = false;
  String? _photoUrl;
  File? _newPhoto;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _typeController = TextEditingController(text: widget.item.type);
    _quantityController = TextEditingController(text: widget.item.quantity.toString());
    _barcodeController = TextEditingController(text: widget.item.barcode ?? '');
    _tags = List.from(widget.item.tags);
    _selectedContainerId = widget.item.containerId;
    _loadPhotoUrl();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _typeController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotoUrl() async {
    if (widget.item.photoPath != null) {
      final itemRepo = ref.read(itemRepositoryProvider);
      final url = await itemRepo.getPhotoUrl(widget.item.photoPath);
      if (mounted) {
        setState(() {
          _photoUrl = url;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _newPhoto = File(image.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    // Validate required fields
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be a positive number')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      final updates = {
        'title': _titleController.text.trim(),
        'type': _typeController.text.trim(),
        'quantity': quantity,
        'barcode': _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        'tags': _tags,
        'containerId': _selectedContainerId,
        'searchText': Item.generateSearchText(
          _titleController.text.trim(),
          _typeController.text.trim(),
          '', // location is deprecated
          _tags,
        ),
      };

      // Handle photo upload BEFORE updating Firestore
      if (_newPhoto != null) {
        final authService = ref.read(authServiceProvider);
        final userId = authService.currentUserId;

        if (userId != null) {
          // Upload photo to storage and get the paths
          final photoPaths = await itemRepo.uploadPhotoToStorage(
            householdId: widget.household.id,
            itemId: widget.item.id,
            userId: userId,
            photo: _newPhoto!,
          );

          // Add photo paths to the updates
          updates['photoPath'] = photoPaths['photoPath'];
          updates['photoThumbPath'] = photoPaths['photoThumbPath'];

          // Delete old photos in background (don't wait for it)
          itemRepo.deleteOldPhotos(
            oldPhotoPath: widget.item.photoPath,
            oldPhotoThumbPath: widget.item.photoThumbPath,
          );
        }
      }

      // Single update with all changes including photo paths
      await itemRepo.updateItem(
        householdId: widget.household.id,
        itemId: widget.item.id,
        updates: updates,
        currentVersion: widget.item.version,
      );

      // Invalidate the items provider to refresh the UI
      ref.invalidate(householdItemsProvider);

      if (mounted) {
        setState(() {
          _isEditMode = false;
          _isLoading = false;
          _newPhoto = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
        // Pop to refresh the list
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating item: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${widget.item.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      await itemRepo.deleteItem(widget.household.id, widget.item.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e')),
        );
      }
    }
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag)) {
      setState(() {
        _tags.add(trimmedTag);
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final containersAsync = ref.watch(allContainersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Item' : 'Item Details'),
        actions: [
          if (!_isEditMode) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
              tooltip: 'Edit',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteItem();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isEditMode = false;
                        // Reset controllers to original values
                        _titleController.text = widget.item.title;
                        _typeController.text = widget.item.type;
                        _quantityController.text = widget.item.quantity.toString();
                        _barcodeController.text = widget.item.barcode ?? '';
                        _tags = List.from(widget.item.tags);
                        _selectedContainerId = widget.item.containerId;
                        _newPhoto = null;
                      });
                    },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: const Text('Save'),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo section
                  _buildPhotoSection(),
                  const SizedBox(height: 24),

                  // Title
                  _isEditMode
                      ? TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            border: OutlineInputBorder(),
                          ),
                        )
                      : _buildInfoRow('Title', widget.item.title),
                  const SizedBox(height: 16),

                  // Type
                  _isEditMode
                      ? TextField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                        )
                      : _buildInfoRow('Type', widget.item.type),
                  const SizedBox(height: 16),

                  // Quantity
                  _isEditMode
                      ? TextField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        )
                      : _buildInfoRow('Quantity', widget.item.quantity.toString()),
                  const SizedBox(height: 16),

                  // Container
                  _isEditMode
                      ? containersAsync.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (error, stack) => Text('Error loading containers: $error'),
                          data: (containers) {
                            // Get the selected container name
                            String selectedName = 'Unorganized';
                            if (_selectedContainerId != null) {
                              final container = containers.firstWhere(
                                (c) => c.id == _selectedContainerId,
                                orElse: () => model.Container(
                                  id: '',
                                  name: 'Unknown',
                                  householdId: '',
                                  containerType: '',
                                  createdAt: DateTime.now(),
                                  lastModified: DateTime.now(),
                                  createdBy: '',
                                ),
                              );
                              selectedName = '${container.name} (${model.Container.getTypeDisplayName(container.containerType)})';
                            }

                            return InkWell(
                              onTap: () async {
                                final result = await showDialog<String?>(
                                  context: context,
                                  builder: (context) => _HierarchicalContainerPickerDialog(
                                    containers: containers,
                                    currentContainerId: _selectedContainerId,
                                  ),
                                );

                                // Only update if user made a selection (not just cancelled)
                                // result can be null (unorganized) or a container ID
                                // If dialog returns null without selecting, result will be null but we shouldn't update
                                // We differentiate by checking if the dialog was dismissed vs unorganized selected
                                if (result != null || (result == null && _selectedContainerId != null)) {
                                  setState(() {
                                    _selectedContainerId = result;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Container',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.arrow_drop_down),
                                ),
                                child: Text(selectedName),
                              ),
                            );
                          },
                        )
                      : containersAsync.when(
                          loading: () => _buildInfoRow('Container', 'Loading...'),
                          error: (error, stack) => _buildInfoRow('Container', 'Error'),
                          data: (containers) {
                            if (_selectedContainerId == null) {
                              return _buildInfoRow('Container', 'Unorganized');
                            }
                            final container = containers.firstWhere(
                              (c) => c.id == _selectedContainerId,
                              orElse: () => model.Container(
                                id: '',
                                name: 'Unknown',
                                householdId: '',
                                containerType: '',
                                createdAt: DateTime.now(),
                                lastModified: DateTime.now(),
                                createdBy: '',
                              ),
                            );
                            return _buildInfoRow(
                              'Container',
                              '${container.name} (${model.Container.getTypeDisplayName(container.containerType)})',
                            );
                          },
                        ),
                  const SizedBox(height: 16),

                  // Barcode
                  if (_isEditMode || (widget.item.barcode != null && widget.item.barcode!.isNotEmpty))
                    Column(
                      children: [
                        _isEditMode
                            ? TextField(
                                controller: _barcodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Barcode',
                                  border: OutlineInputBorder(),
                                ),
                              )
                            : _buildInfoRow('Barcode', widget.item.barcode ?? ''),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Book-specific information (if this is a book)
                  if (widget.item.type == 'book') ...[
                    _buildBookInfoSection(),
                    const SizedBox(height: 24),
                  ],

                  // Tags
                  _buildTagsSection(),
                  const SizedBox(height: 24),

                  // Metadata
                  _buildMetadataSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoSection() {
    if (_isEditMode && _newPhoto != null) {
      return Column(
        children: [
          GestureDetector(
            onTap: () => _showFullScreenPhoto(isLocalFile: true),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.file(
                    _newPhoto!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Change Photo'),
          ),
        ],
      );
    } else if (_photoUrl != null) {
      return Column(
        children: [
          GestureDetector(
            onTap: () => _showFullScreenPhoto(isLocalFile: false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: _photoUrl!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 250,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 250,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, size: 50),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isEditMode) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Change Photo'),
            ),
          ],
        ],
      );
    } else if (_isEditMode) {
      return ElevatedButton.icon(
        onPressed: _pickImage,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Add Photo'),
      );
    }
    return const SizedBox.shrink();
  }

  void _showFullScreenPhoto({required bool isLocalFile}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenPhotoViewer(
          photoUrl: _photoUrl,
          localPhoto: _newPhoto,
          isLocalFile: isLocalFile,
          itemTitle: widget.item.title,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tags',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            if (_isEditMode)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final tag = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      final controller = TextEditingController();
                      return AlertDialog(
                        title: const Text('Add Tag'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Tag name',
                            border: OutlineInputBorder(),
                          ),
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, controller.text),
                            child: const Text('Add'),
                          ),
                        ],
                      );
                    },
                  );
                  if (tag != null && tag.isNotEmpty) {
                    _addTag(tag);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        _tags.isEmpty
            ? Text(
                'No tags',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: _isEditMode ? () => _removeTag(tag) : null,
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildBookInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Book Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Authors
            if (widget.item.authors != null && widget.item.authors!.isNotEmpty) ...[
              _buildInfoRow(
                'Author${widget.item.authors!.length > 1 ? "s" : ""}',
                widget.item.authors!.join(', '),
              ),
              const SizedBox(height: 12),
            ],

            // Publisher
            if (widget.item.publisher != null && widget.item.publisher!.isNotEmpty) ...[
              _buildInfoRow('Publisher', widget.item.publisher!),
              const SizedBox(height: 12),
            ],

            // ISBN
            if (widget.item.isbn != null && widget.item.isbn!.isNotEmpty) ...[
              _buildInfoRow('ISBN', widget.item.isbn!),
              const SizedBox(height: 12),
            ],

            // Page Count
            if (widget.item.pageCount != null) ...[
              _buildInfoRow('Pages', widget.item.pageCount.toString()),
              const SizedBox(height: 12),
            ],

            // Description
            if (widget.item.description != null && widget.item.description!.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metadata',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Created',
              '${_formatDate(widget.item.createdAt)} by ${widget.item.createdBy}',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Last Modified',
              _formatDate(widget.item.lastModified),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Version',
              widget.item.version.toString(),
            ),
            if (widget.item.syncStatus != SyncStatus.synced) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Sync Status',
                widget.item.syncStatus.toString().split('.').last,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Full-screen photo viewer
class _FullScreenPhotoViewer extends StatefulWidget {
  final String? photoUrl;
  final File? localPhoto;
  final bool isLocalFile;
  final String itemTitle;

  const _FullScreenPhotoViewer({
    this.photoUrl,
    this.localPhoto,
    required this.isLocalFile,
    required this.itemTitle,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // Reset zoom
      _transformationController.value = Matrix4.identity();
    } else {
      // Zoom in to 2x at the tap position
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translateByDouble(-position.dx, -position.dy, 0, 0)
        ..scaleByDouble(2.0, 2.0, 1.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.itemTitle,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: SizedBox.expand(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: widget.isLocalFile
                  ? Image.file(
                      widget.localPhoto!,
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      widget.photoUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.white, size: 50),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Pinch to zoom • Double tap to zoom in/out',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

// Hierarchical Container Picker Dialog
class _HierarchicalContainerPickerDialog extends StatefulWidget {
  final List<model.Container> containers;
  final String? currentContainerId;

  const _HierarchicalContainerPickerDialog({
    required this.containers,
    this.currentContainerId,
  });

  @override
  State<_HierarchicalContainerPickerDialog> createState() =>
      _HierarchicalContainerPickerDialogState();
}

class _HierarchicalContainerPickerDialogState
    extends State<_HierarchicalContainerPickerDialog> {
  final Set<String> _expandedContainers = {};

  @override
  void initState() {
    super.initState();
    // Auto-expand path to currently selected container
    if (widget.currentContainerId != null) {
      _expandPathToContainer(widget.currentContainerId!);
    }
  }

  void _expandPathToContainer(String containerId) {
    if (widget.containers.isEmpty) return;

    try {
      final container = widget.containers.firstWhere(
        (c) => c.id == containerId,
      );

      // Expand all parents
      String? parentId = container.parentId;
      while (parentId != null) {
        _expandedContainers.add(parentId);
        try {
          final parent = widget.containers.firstWhere(
            (c) => c.id == parentId,
          );
          parentId = parent.parentId;
        } catch (e) {
          break; // Parent not found, stop expanding
        }
      }
    } catch (e) {
      // Container not found, do nothing
    }
  }

  List<model.Container> _getTopLevelContainers() {
    return widget.containers.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<model.Container> _getChildContainers(String parentId) {
    return widget.containers.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  bool _hasChildren(String containerId) {
    return widget.containers.any((c) => c.parentId == containerId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Container'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            // Unorganized option
            ListTile(
              leading: const Icon(Icons.inbox, color: Colors.orange),
              title: const Text('Unorganized'),
              subtitle: const Text('Not in any container'),
              selected: widget.currentContainerId == null,
              selectedTileColor: Colors.orange.withOpacity(0.1),
              onTap: () => Navigator.pop(context, null),
            ),
            const Divider(),
            // Hierarchical containers
            ..._buildContainerTree(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  List<Widget> _buildContainerTree() {
    final topLevel = _getTopLevelContainers();
    final widgets = <Widget>[];

    for (final container in topLevel) {
      widgets.addAll(_buildContainerTile(container, 0));
    }

    return widgets;
  }

  List<Widget> _buildContainerTile(model.Container container, int level) {
    final hasChildren = _hasChildren(container.id);
    final isExpanded = _expandedContainers.contains(container.id);
    final children = _getChildContainers(container.id);
    final isSelected = widget.currentContainerId == container.id;

    final widgets = <Widget>[];

    if (hasChildren) {
      // Container with children - use ExpansionTile
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: level * 16.0),
          child: ExpansionTile(
            key: PageStorageKey(container.id),
            leading: Icon(_getContainerIcon(container)),
            title: Text(container.name),
            subtitle: Text(model.Container.getTypeDisplayName(container.containerType)),
            initiallyExpanded: isExpanded,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const Icon(Icons.expand_more),
              ],
            ),
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedContainers.add(container.id);
                } else {
                  _expandedContainers.remove(container.id);
                }
              });
            },
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: EdgeInsets.zero,
            children: [
              // Add a "Select this container" option
              Padding(
                padding: EdgeInsets.only(left: (level + 1) * 16.0),
                child: ListTile(
                  leading: const SizedBox(width: 40), // Spacer to align with icon
                  title: Text('Select "${container.name}"'),
                  selected: isSelected,
                  selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  onTap: () => Navigator.pop(context, container.id),
                  dense: true,
                ),
              ),
              // Add child containers
              ...children.expand((child) => _buildContainerTile(child, level + 1)),
            ],
          ),
        ),
      );
    } else {
      // Leaf container - simple ListTile
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: level * 16.0),
          child: ListTile(
            leading: Icon(_getContainerIcon(container)),
            title: Text(container.name),
            subtitle: Text(model.Container.getTypeDisplayName(container.containerType)),
            selected: isSelected,
            selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : null,
            onTap: () => Navigator.pop(context, container.id),
          ),
        ),
      );
    }

    return widgets;
  }

  IconData _getContainerIcon(model.Container container) {
    switch (container.containerType.toLowerCase()) {
      case 'room':
        return Icons.meeting_room;
      case 'shelf':
        return Icons.shelves;
      case 'box':
        return Icons.inventory_2;
      case 'cabinet':
        return Icons.kitchen;
      case 'drawer':
        return Icons.widgets;
      case 'closet':
        return Icons.checkroom;
      default:
        return Icons.inventory_2;
    }
  }
}
