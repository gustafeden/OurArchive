import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/vinyl_metadata.dart';
import 'barcode_scan_screen.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  final Household? household;
  final String? householdId; // Alternative to household object
  final String? preSelectedContainerId;
  final BookMetadata? bookData;
  final VinylMetadata? vinylData;

  const AddItemScreen({
    super.key,
    this.household,
    this.householdId,
    this.preSelectedContainerId,
    this.bookData,
    this.vinylData,
  }) : assert(household != null || householdId != null,
            'Either household or householdId must be provided');

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _tagsController = TextEditingController();

  String _selectedType = 'general';
  String? _selectedContainerId;
  File? _photo;
  bool _isLoading = false;

  // Helper to get household ID from either household object or direct ID
  String get _householdId => widget.householdId ?? widget.household!.id;

  final List<String> _itemTypes = [
    'general',
    'tool',
    'pantry',
    'camera',
    'book',
    'vinyl',
    'game',
    'electronics',
    'clothing',
    'kitchen',
    'outdoor',
  ];

  @override
  void initState() {
    super.initState();
    _selectedContainerId = widget.preSelectedContainerId;

    // Pre-fill form if book data is provided
    if (widget.bookData != null) {
      _titleController.text = widget.bookData!.title ?? '';
      _selectedType = 'book';

      // Add book-specific info to tags
      final bookTags = <String>[];
      if (widget.bookData!.authors.isNotEmpty) {
        bookTags.add('author:${widget.bookData!.authors.first}');
      }
      if (widget.bookData!.publisher != null) {
        bookTags.add('publisher:${widget.bookData!.publisher}');
      }
      _tagsController.text = bookTags.join(', ');

      // Download book cover if available
      if (widget.bookData!.thumbnailUrl != null) {
        _downloadBookCover(widget.bookData!.thumbnailUrl!);
      }
    }

    // Pre-fill form if vinyl data is provided
    if (widget.vinylData != null) {
      _titleController.text = widget.vinylData!.title;
      _selectedType = 'vinyl';

      // Add vinyl-specific info to tags
      final vinylTags = <String>[];
      if (widget.vinylData!.artist.isNotEmpty) {
        vinylTags.add('artist:${widget.vinylData!.artist}');
      }
      if (widget.vinylData!.label != null) {
        vinylTags.add('label:${widget.vinylData!.label}');
      }
      if (widget.vinylData!.genre != null) {
        vinylTags.add('genre:${widget.vinylData!.genre}');
      }
      _tagsController.text = vinylTags.join(', ');

      // Download vinyl cover if available
      if (widget.vinylData!.coverUrl != null) {
        _downloadBookCover(widget.vinylData!.coverUrl!);
      }
    }
  }

  Future<void> _downloadBookCover(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/book_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          setState(() {
            _photo = file;
          });
        }
      }
    } catch (e) {
      // Silently fail - user can add photo manually
      debugPrint('Failed to download book cover: $e');
    }
  }

  Future<void> _scanBook() async {
    // Only allow scanning if we have the full household object
    if (widget.household == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot scan books from this screen')),
      );
      return;
    }

    // Navigate to BarcodeScanScreen for batch scanning
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScanScreen(
          household: widget.household!,
          preSelectedContainerId: widget.preSelectedContainerId,
        ),
      ),
    );

    // If we return here, the user finished scanning
    // Close this screen too since books are added during scanning
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _photo = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _photo = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId!;

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final itemData = {
        'title': _titleController.text.trim(),
        'type': _selectedType,
        'location': _locationController.text.trim(),
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'tags': tags,
        'archived': false,
        'sortOrder': 0,
        'containerId': _selectedContainerId,
      };

      // Add book-specific fields if available
      if (widget.bookData != null) {
        itemData['authors'] = widget.bookData!.authors;
        itemData['publisher'] = widget.bookData!.publisher;
        itemData['isbn'] = widget.bookData!.isbn;
        itemData['coverUrl'] = widget.bookData!.thumbnailUrl;
        itemData['pageCount'] = widget.bookData!.pageCount;
        itemData['description'] = widget.bookData!.description;
        itemData['barcode'] = widget.bookData!.isbn;
      }

      // Add vinyl-specific fields if available
      if (widget.vinylData != null) {
        itemData['artist'] = widget.vinylData!.artist;
        itemData['label'] = widget.vinylData!.label;
        itemData['releaseYear'] = widget.vinylData!.year;
        itemData['genre'] = widget.vinylData!.genre;
        itemData['styles'] = widget.vinylData!.styles;
        itemData['catalogNumber'] = widget.vinylData!.catalogNumber;
        itemData['coverUrl'] = widget.vinylData!.coverUrl;
        itemData['format'] = widget.vinylData!.format;
        itemData['country'] = widget.vinylData!.country;
        itemData['discogsId'] = widget.vinylData!.discogsId;
        itemData['barcode'] = '${widget.vinylData!.discogsId}'; // Use Discogs ID as barcode fallback
      }

      await itemRepo.addItem(
        householdId: _householdId,
        userId: userId,
        itemData: itemData,
        photo: _photo,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        actions: [
          // Only show scan button if we have full household object
          if (widget.household != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan Book',
              onPressed: _scanBook,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo section
            if (_photo != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(_photo!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() => _photo = null);
                    },
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Gallery'),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g., Drill, Laptop, Pasta',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
              enabled: !_isLoading,
            ),

            const SizedBox(height: 16),

            // Type dropdown
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: _itemTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type[0].toUpperCase() + type.substring(1)),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() => _selectedType = value!);
                    },
            ),

            const SizedBox(height: 16),

            // Container dropdown
            _buildContainerDropdown(),

            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g., Garage, Kitchen, Basement',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              enabled: !_isLoading,
            ),

            const SizedBox(height: 16),

            // Quantity
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final qty = int.tryParse(value ?? '');
                if (qty == null || qty < 1) {
                  return 'Please enter a valid quantity';
                }
                return null;
              },
              enabled: !_isLoading,
            ),

            const SizedBox(height: 16),

            // Tags
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'e.g., power tools, red, birthday gift',
                helperText: 'Separate tags with commas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              enabled: !_isLoading,
            ),

            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveItem,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Saving...' : 'Save Item'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerDropdown() {
    final allContainersAsync = ref.watch(allContainersProvider);

    return allContainersAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) => Text('Error loading containers: $error'),
      data: (containers) {
        if (containers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No containers yet. Create rooms and containers to organize your items.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        // Build hierarchical list of containers
        final containerItems = _buildContainerMenuItems(containers);

        return DropdownButtonFormField<String?>(
          value: _selectedContainerId,
          decoration: const InputDecoration(
            labelText: 'Container (optional)',
            hintText: 'Select a room or container',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.inventory_2),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('None (unorganized)'),
            ),
            ...containerItems,
          ],
          onChanged: _isLoading
              ? null
              : (value) {
                  setState(() => _selectedContainerId = value);
                },
        );
      },
    );
  }

  List<DropdownMenuItem<String?>> _buildContainerMenuItems(List containers) {
    // Create a map for quick parent lookup
    final containerMap = {for (var c in containers) c.id: c};

    // Get top-level containers (rooms)
    final topLevel = containers.where((c) => c.parentId == null).toList();
    topLevel.sort((a, b) => a.name.compareTo(b.name));

    final items = <DropdownMenuItem<String?>>[];

    for (final container in topLevel) {
      // Add the top-level container
      items.add(
        DropdownMenuItem<String?>(
          value: container.id,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getContainerIconForType(container.containerType), size: 20),
              const SizedBox(width: 8),
              Text(container.name),
            ],
          ),
        ),
      );

      // Add children recursively
      _addChildContainers(items, containers, container.id, containerMap, 1);
    }

    return items;
  }

  void _addChildContainers(
    List<DropdownMenuItem<String?>> items,
    List containers,
    String parentId,
    Map containerMap,
    int depth,
  ) {
    final children = containers.where((c) => c.parentId == parentId).toList();
    children.sort((a, b) => a.name.compareTo(b.name));

    for (final child in children) {
      final indent = '  ' * depth;
      items.add(
        DropdownMenuItem<String?>(
          value: child.id,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(indent),
              Icon(_getContainerIconForType(child.containerType), size: 20),
              const SizedBox(width: 8),
              Text(child.name),
            ],
          ),
        ),
      );

      // Recursively add children
      _addChildContainers(items, containers, child.id, containerMap, depth + 1);
    }
  }

  IconData _getContainerIconForType(String type) {
    switch (type) {
      case 'room':
        return Icons.meeting_room;
      case 'shelf':
        return Icons.shelves;
      case 'box':
        return Icons.inventory_2;
      case 'fridge':
        return Icons.kitchen;
      case 'drawer':
        return Icons.kitchen_outlined;
      case 'cabinet':
        return Icons.door_sliding;
      case 'closet':
        return Icons.checkroom;
      case 'bin':
        return Icons.delete_outline;
      default:
        return Icons.inventory_2;
    }
  }
}
