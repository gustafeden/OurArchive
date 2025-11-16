import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/book_metadata.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  final Household? household;
  final String? householdId; // Alternative to household object
  final String? preSelectedContainerId;
  final BookMetadata? bookData;

  const AddBookScreen({
    super.key,
    this.household,
    this.householdId,
    this.preSelectedContainerId,
    this.bookData,
  }) : assert(household != null || householdId != null,
            'Either household or householdId must be provided');

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _isbnController = TextEditingController();
  final _publisherController = TextEditingController();
  final _yearController = TextEditingController();
  final _notesController = TextEditingController();

  final List<TextEditingController> _authorControllers = [TextEditingController()];

  File? _photo;
  String? _selectedContainerId;
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
      _isbnController.text = widget.bookData!.isbn;
      _publisherController.text = widget.bookData!.publisher ?? '';

      // Extract year from publishedDate if available
      if (widget.bookData!.publishedDate != null) {
        final yearMatch = RegExp(r'\d{4}').firstMatch(widget.bookData!.publishedDate!);
        if (yearMatch != null) {
          _yearController.text = yearMatch.group(0)!;
        }
      }

      // Pre-fill authors
      if (widget.bookData!.authors.isNotEmpty) {
        _authorControllers.clear();
        for (var author in widget.bookData!.authors) {
          final controller = TextEditingController(text: author);
          _authorControllers.add(controller);
        }
      }

      _notesController.text = widget.bookData!.description ?? '';

      // Download book cover if available
      if (widget.bookData!.thumbnailUrl != null) {
        _downloadBookCover(widget.bookData!.thumbnailUrl!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _notesController.dispose();
    for (var controller in _authorControllers) {
      controller.dispose();
    }
    super.dispose();
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
      debugPrint('Failed to download book cover: $e');
    }
  }

  void _addAuthorField() {
    setState(() {
      _authorControllers.add(TextEditingController());
    });
  }

  void _removeAuthorField(int index) {
    if (_authorControllers.length > 1) {
      setState(() {
        _authorControllers[index].dispose();
        _authorControllers.removeAt(index);
      });
    }
  }

  Future<void> _takephoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _photo = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _photo = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId!;

      // Collect non-empty authors
      final authors = _authorControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final itemData = {
        'title': _titleController.text.trim(),
        'type': 'book',
        'location': '', // Deprecated but keep empty
        'quantity': 1,
        'tags': [], // No tags, we use structured fields
        'archived': false,
        'sortOrder': 0,
        'containerId': _selectedContainerId,
        'authors': authors,
        'publisher': _publisherController.text.trim().isEmpty ? null : _publisherController.text.trim(),
        'isbn': _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
        'coverUrl': widget.bookData?.thumbnailUrl,
        'pageCount': widget.bookData?.pageCount,
        'description': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'barcode': _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
      };

      // Add year if provided
      if (_yearController.text.trim().isNotEmpty) {
        itemData['publishedDate'] = _yearController.text.trim();
      }

      await itemRepo.addItem(
        householdId: _householdId,
        userId: userId,
        itemData: itemData,
        photo: _photo,
      );

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding book: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final containersAsync = ref.watch(allContainersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Book'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveBook,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Photo Section
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Take Photo'),
                          onTap: () {
                            Navigator.pop(context);
                            _takephoto();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choose from Gallery'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickPhotoFromGallery();
                          },
                        ),
                        if (_photo != null)
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text('Remove Photo'),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _photo = null);
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_photo!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.book, size: 64, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Tap to add cover photo',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Title (Required)
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Authors (Multi-entry)
            const Text('Authors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ..._authorControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Author name',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person),
                          suffixIcon: _authorControllers.length > 1
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _removeAuthorField(index),
                                )
                              : null,
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addAuthorField,
              icon: const Icon(Icons.add),
              label: const Text('Add Another Author'),
            ),
            const SizedBox(height: 16),

            // ISBN (Optional)
            TextFormField(
              controller: _isbnController,
              decoration: const InputDecoration(
                labelText: 'ISBN (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Publisher & Year (Row)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _publisherController,
                    decoration: const InputDecoration(
                      labelText: 'Publisher',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Container/Location
            containersAsync.when(
              data: (containers) {
                return DropdownButtonFormField<String>(
                  value: _selectedContainerId,
                  decoration: const InputDecoration(
                    labelText: 'Container (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No container'),
                    ),
                    ...containers.map((container) {
                      return DropdownMenuItem<String>(
                        value: container.id,
                        child: Text(container.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedContainerId = value;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load containers'),
            ),
            const SizedBox(height: 16),

            // Notes/Description
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Description (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
