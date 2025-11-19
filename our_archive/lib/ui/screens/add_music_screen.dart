import 'package:ionicons/ionicons.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/music_metadata.dart';
import '../../data/models/track.dart';
import '../../data/models/discogs_search_result.dart';
import '../../services/music_lookup_service.dart';
import '../widgets/scanner/music_selection_dialog.dart';
import '../widgets/common/photo_picker_widget.dart';
import '../widgets/common/loading_button.dart';
import '../widgets/form/container_selector_field.dart';
import '../widgets/form/year_field.dart';
import '../widgets/form/notes_field.dart';

class AddMusicScreen extends ConsumerStatefulWidget {
  final Household? household;
  final String? householdId; // Alternative to household object
  final String? preSelectedContainerId;
  final MusicMetadata? musicData;
  final List<Track>? tracks; // Pre-loaded tracks from scanner

  const AddMusicScreen({
    super.key,
    this.household,
    this.householdId,
    this.preSelectedContainerId,
    this.musicData,
    this.tracks,
  }) : assert(household != null || householdId != null,
            'Either household or householdId must be provided');

  @override
  ConsumerState<AddMusicScreen> createState() => _AddMusicScreenState();
}

class _AddMusicScreenState extends ConsumerState<AddMusicScreen> {
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

    if (widget.musicData != null) {
      _titleController.text = widget.musicData!.title;
      _artistController.text = widget.musicData!.artist;
      _labelController.text = widget.musicData!.label ?? '';
      _yearController.text = widget.musicData!.year ?? '';
      _genreController.text = widget.musicData!.genre ?? '';
      _catalogController.text = widget.musicData!.catalogNumber ?? '';

      // Auto-select format based on API data
      if (widget.musicData!.format != null && widget.musicData!.format!.isNotEmpty) {
        final formatLower = widget.musicData!.format!.join(' ').toLowerCase();
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

      if (widget.musicData!.coverUrl != null) {
        _downloadCover(widget.musicData!.coverUrl!);
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
        final file = File('${tempDir.path}/music_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) setState(() => _photo = file);
      }
    } catch (e) {
      debugPrint('Failed to download cover: $e');
    }
  }


  Future<void> _saveMusic() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      final authService = ref.read(authServiceProvider);

      final itemData = {
        'title': _titleController.text.trim(),
        'type': 'music',
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
        'coverUrl': widget.musicData?.coverUrl,
        'description': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'discogsId': widget.musicData?.discogsId,
        'barcode': widget.musicData?.barcode, // Store the actual UPC/EAN barcode
        'tracks': widget.tracks?.map((t) => t.toJson()).toList(), // Save pre-loaded tracks
      };

      // Save format based on user selection or API data
      if (widget.musicData != null && widget.musicData!.format != null) {
        // Use API format if available
        itemData['format'] = widget.musicData!.format;
        itemData['styles'] = widget.musicData!.styles;
        itemData['country'] = widget.musicData!.country;
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

  // Allow user to select a different release while preserving form inputs
  Future<void> _selectDifferentRelease() async {
    if (widget.musicData?.barcode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No barcode available to search for other releases')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Fetch all releases for this barcode
      final itemRepository = ref.read(itemRepositoryProvider);
      final results = await Future.wait([
        MusicLookupService.lookupByBarcodeWithPagination(widget.musicData!.barcode!),
        itemRepository.findAllItemsByBarcode(_householdId, widget.musicData!.barcode!),
      ]);

      final searchResult = results[0] as DiscogsSearchResult;
      final ownedItems = results[1] as List;

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (searchResult.results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No other releases found')),
          );
        }
        return;
      }

      // Show selection dialog
      final selectionResult = await showMusicSelectionDialog(
        context: context,
        barcode: widget.musicData!.barcode!,
        initialResults: searchResult.results,
        initialPagination: searchResult.pagination,
        ownedItems: ownedItems.cast(),
        householdId: _householdId,
      );

      if (selectionResult != null && mounted) {
        // Extract music metadata from result
        final selectedMusic = selectionResult.music;

        // Update metadata fields while preserving user inputs
        setState(() {
          _titleController.text = selectedMusic.title;
          _artistController.text = selectedMusic.artist;
          _labelController.text = selectedMusic.label ?? '';
          _yearController.text = selectedMusic.year ?? '';
          _genreController.text = selectedMusic.genre ?? '';
          _catalogController.text = selectedMusic.catalogNumber ?? '';

          // Update format based on new release
          if (selectedMusic.format != null && selectedMusic.format!.isNotEmpty) {
            final formatLower = selectedMusic.format!.join(' ').toLowerCase();
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

          // Download new cover
          if (selectedMusic.coverUrl != null) {
            _downloadCover(selectedMusic.coverUrl!);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to: ${selectedMusic.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading releases: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Music'),
        actions: [
          if (widget.musicData?.barcode != null)
            TextButton.icon(
              onPressed: _selectDifferentRelease,
              icon: const Icon(Ionicons.swap_horizontal_outline),
              label: const Text('Different Release'),
            ),
          LoadingButton(
            isLoading: _isLoading,
            onPressed: _saveMusic,
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
              placeholderIcon: Ionicons.disc_outline,
              placeholderText: 'Tap to add cover photo',
            ),
            const SizedBox(height: 24),
            TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder(), prefixIcon: Icon(Ionicons.text_outline)), validator: (v) => v?.trim().isEmpty ?? true ? 'Title is required' : null, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 16),
            TextFormField(controller: _artistController, decoration: const InputDecoration(labelText: 'Artist', border: OutlineInputBorder(), prefixIcon: Icon(Ionicons.person_outline)), textCapitalization: TextCapitalization.words),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedFormat,
              decoration: const InputDecoration(
                labelText: 'Format',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Ionicons.disc_outline),
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
              Expanded(flex: 2, child: TextFormField(controller: _labelController, decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder(), prefixIcon: Icon(Ionicons.business_outline)), textCapitalization: TextCapitalization.words)),
              const SizedBox(width: 12),
              Expanded(child: YearField(controller: _yearController)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _genreController, decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder(), prefixIcon: Icon(Ionicons.musical_note_outline)), textCapitalization: TextCapitalization.words)),
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
