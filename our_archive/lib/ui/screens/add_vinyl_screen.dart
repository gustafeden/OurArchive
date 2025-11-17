import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/vinyl_metadata.dart';
import '../widgets/common/photo_picker_widget.dart';
import '../widgets/common/loading_button.dart';
import '../widgets/form/container_selector_field.dart';
import '../widgets/form/year_field.dart';
import '../widgets/form/notes_field.dart';

class AddVinylScreen extends ConsumerStatefulWidget {
  final Household? household;
  final String? householdId; // Alternative to household object
  final String? preSelectedContainerId;
  final VinylMetadata? vinylData;

  const AddVinylScreen({
    super.key,
    this.household,
    this.householdId,
    this.preSelectedContainerId,
    this.vinylData,
  }) : assert(household != null || householdId != null,
            'Either household or householdId must be provided');

  @override
  ConsumerState<AddVinylScreen> createState() => _AddVinylScreenState();
}

class _AddVinylScreenState extends ConsumerState<AddVinylScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _labelController = TextEditingController();
  final _yearController = TextEditingController();
  final _genreController = TextEditingController();
  final _catalogController = TextEditingController();
  final _notesController = TextEditingController();

  File? _photo;
  String? _selectedContainerId;
  String _selectedFormat = 'vinyl';
  bool _isLoading = false;

  final List<String> _formats = ['vinyl', 'cd', 'cassette', 'digital', 'other'];

  // Helper to get household ID from either household object or direct ID
  String get _householdId => widget.householdId ?? widget.household!.id;

  @override
  void initState() {
    super.initState();
    _selectedContainerId = widget.preSelectedContainerId;

    if (widget.vinylData != null) {
      _titleController.text = widget.vinylData!.title;
      _artistController.text = widget.vinylData!.artist;
      _labelController.text = widget.vinylData!.label ?? '';
      _yearController.text = widget.vinylData!.year ?? '';
      _genreController.text = widget.vinylData!.genre ?? '';
      _catalogController.text = widget.vinylData!.catalogNumber ?? '';

      // Auto-select format based on API data
      if (widget.vinylData!.format != null && widget.vinylData!.format!.isNotEmpty) {
        final formatLower = widget.vinylData!.format!.join(' ').toLowerCase();
        if (formatLower.contains('cd')) {
          _selectedFormat = 'cd';
        } else if (formatLower.contains('vinyl') || formatLower.contains('lp')) {
          _selectedFormat = 'vinyl';
        } else if (formatLower.contains('cassette')) {
          _selectedFormat = 'cassette';
        } else if (formatLower.contains('digital') || formatLower.contains('file')) {
          _selectedFormat = 'digital';
        }
      }

      if (widget.vinylData!.coverUrl != null) {
        _downloadCover(widget.vinylData!.coverUrl!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _labelController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    _catalogController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _downloadCover(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/vinyl_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) setState(() => _photo = file);
      }
    } catch (e) {
      debugPrint('Failed to download cover: $e');
    }
  }


  Future<void> _saveVinyl() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      final authService = ref.read(authServiceProvider);

      final itemData = {
        'title': _titleController.text.trim(),
        'type': 'vinyl',
        'location': '',
        'quantity': 1,
        'tags': [],
        'archived': false,
        'sortOrder': 0,
        'containerId': _selectedContainerId,
        'artist': _artistController.text.trim().isEmpty ? null : _artistController.text.trim(),
        'label': _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
        'releaseYear': _yearController.text.trim().isEmpty ? null : _yearController.text.trim(),
        'genre': _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        'catalogNumber': _catalogController.text.trim().isEmpty ? null : _catalogController.text.trim(),
        'coverUrl': widget.vinylData?.coverUrl,
        'description': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'discogsId': widget.vinylData?.discogsId,
        'barcode': widget.vinylData?.barcode, // Store the actual UPC/EAN barcode
      };

      // Save format based on user selection or API data
      if (widget.vinylData != null && widget.vinylData!.format != null) {
        // Use API format if available
        itemData['format'] = widget.vinylData!.format;
        itemData['styles'] = widget.vinylData!.styles;
        itemData['country'] = widget.vinylData!.country;
      } else {
        // Convert user selection to format array for manual entries
        switch (_selectedFormat) {
          case 'cd':
            itemData['format'] = ['CD'];
            break;
          case 'vinyl':
            itemData['format'] = ['Vinyl'];
            break;
          case 'cassette':
            itemData['format'] = ['Cassette'];
            break;
          case 'digital':
            itemData['format'] = ['Digital File'];
            break;
          case 'other':
            itemData['format'] = ['Unknown'];
            break;
        }
      }

      await itemRepo.addItem(
        householdId: _householdId,
        userId: authService.currentUserId!,
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
              route.isFirst,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Music added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Music'),
        actions: [
          LoadingButton(
            isLoading: _isLoading,
            onPressed: _saveVinyl,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PhotoPickerWidget(
              photo: _photo,
              onPhotoChanged: (photo) => setState(() => _photo = photo),
              placeholderIcon: Icons.album,
              placeholderText: 'Tap to add cover photo',
            ),
            const SizedBox(height: 24),
            TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title)), validator: (v) => v?.trim().isEmpty ?? true ? 'Title is required' : null, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 16),
            TextFormField(controller: _artistController, decoration: const InputDecoration(labelText: 'Artist', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)), textCapitalization: TextCapitalization.words),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedFormat,
              decoration: const InputDecoration(
                labelText: 'Format',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.album),
              ),
              items: _formats.map((format) {
                return DropdownMenuItem(
                  value: format,
                  child: Text(format.substring(0, 1).toUpperCase() + format.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedFormat = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(flex: 2, child: TextFormField(controller: _labelController, decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)), textCapitalization: TextCapitalization.words)),
              const SizedBox(width: 12),
              Expanded(child: YearField(controller: _yearController)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _genreController, decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder(), prefixIcon: Icon(Icons.music_note)), textCapitalization: TextCapitalization.words)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _catalogController, decoration: const InputDecoration(labelText: 'Catalog #', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 16),
            ContainerSelectorField(
              selectedContainerId: _selectedContainerId,
              onChanged: (v) => setState(() => _selectedContainerId = v),
            ),
            const SizedBox(height: 16),
            NotesField(controller: _notesController),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
