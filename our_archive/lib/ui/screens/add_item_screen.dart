import 'package:ionicons/ionicons.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/book_metadata.dart';
import '../../data/models/music_metadata.dart';
import '../../utils/icon_helper.dart';
import 'barcode_scan_screen.dart';
import '../widgets/common/photo_picker_widget.dart';
import '../widgets/form/hierarchical_container_picker.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  final Household? household;
  final String? householdId; // Alternative to household object
  final String? preSelectedContainerId;
  final BookMetadata? bookData;
  final MusicMetadata? musicData;

  const AddItemScreen({
    super.key,
    this.household,
    this.householdId,
    this.preSelectedContainerId,
    this.bookData,
    this.musicData,
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

    // Pre-fill form if music data is provided
    if (widget.musicData != null) {
      _titleController.text = widget.musicData!.title;
      _selectedType = 'music';

      // Add music-specific info to tags
      final musicTags = <String>[];
      if (widget.musicData!.artist.isNotEmpty) {
        musicTags.add('artist:${widget.musicData!.artist}');
      }
      if (widget.musicData!.label != null) {
        musicTags.add('label:${widget.musicData!.label}');
      }
      if (widget.musicData!.genre != null) {
        musicTags.add('genre:${widget.musicData!.genre}');
      }
      _tagsController.text = musicTags.join(', ');

      // Download music cover if available
      if (widget.musicData!.coverUrl != null) {
        _downloadBookCover(widget.musicData!.coverUrl!);
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
          householdId: widget.household!.id,
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

      // Add music-specific fields if available
      if (widget.musicData != null) {
        itemData['artist'] = widget.musicData!.artist;
        itemData['label'] = widget.musicData!.label;
        itemData['releaseYear'] = widget.musicData!.year;
        itemData['genre'] = widget.musicData!.genre;
        itemData['styles'] = widget.musicData!.styles;
        itemData['catalogNumber'] = widget.musicData!.catalogNumber;
        itemData['coverUrl'] = widget.musicData!.coverUrl;
        itemData['format'] = widget.musicData!.format;
        itemData['country'] = widget.musicData!.country;
        itemData['discogsId'] = widget.musicData!.discogsId;
        itemData['barcode'] = '${widget.musicData!.discogsId}'; // Use Discogs ID as barcode fallback
      }

      await itemRepo.addItem(
        householdId: _householdId,
        userId: userId,
        itemData: itemData,
        photo: _photo,
      );

      if (mounted) {
        // Pop all screens and return to the main list/container screen
        Navigator.popUntil(
          context,
          (route) =>
              route.settings.name == '/item_list' ||
              route.settings.name == '/container' ||
              route.settings.name == '/household_home' ||
              route.isFirst,
        );
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
              icon: const Icon(Ionicons.qr_code_outline),
              tooltip: 'Scan Book',
              onPressed: _scanBook,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Information Section
            Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 8),
              child: Text(
                'BASIC INFORMATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

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
                  return 'Title is required';
                }
                if (value.trim().length < 2) {
                  return 'Title must be at least 2 characters';
                }
                return null;
              },
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            // Type dropdown
            Consumer(
              builder: (context, ref, child) {
                final itemTypesAsync = ref.watch(itemTypesProvider(_householdId));

                return itemTypesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => Text('Error loading types: $error'),
                  data: (itemTypes) {
                    // Show all item types
                    final availableTypes = itemTypes;

                    // Ensure _selectedType exists in available types
                    if (!availableTypes.any((t) => t.name == _selectedType)) {
                      if (availableTypes.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() => _selectedType = availableTypes.first.name);
                        });
                      }
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: availableTypes.map((type) {
                        return DropdownMenuItem(
                          value: type.name,
                          child: Row(
                            children: [
                              Icon(IconHelper.getIconData(type.icon), size: 20),
                              const SizedBox(width: 8),
                              Text(type.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() => _selectedType = value!);
                            },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Photo section
            PhotoPickerWidget(
              photo: _photo,
              onPhotoChanged: (photo) => setState(() => _photo = photo),
            ),

            const SizedBox(height: 16),

            // Organization Section
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Text(
                'ORGANIZATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Container picker
            HierarchicalContainerPicker(
              selectedContainerId: _selectedContainerId,
              onChanged: (value) {
                setState(() => _selectedContainerId = value);
              },
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
                prefixIcon: Icon(Ionicons.pricetag_outline),
              ),
              enabled: !_isLoading,
            ),

            const SizedBox(height: 16),

            // Notes Section
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Text(
                'NOTES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g., Garage, Kitchen, Basement',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Ionicons.location_outline),
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
                  : const Icon(Ionicons.save_outline),
              label: Text(_isLoading ? 'Saving...' : 'Save Item'),
            ),
          ],
        ),
      ),
    );
  }

}
