import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../../data/models/vinyl_metadata.dart';
import '../theme/extensions/context_ext.dart';
import '../widgets/forms/app_text_field.dart';
import '../widgets/forms/app_photo_picker_field.dart';
import '../widgets/forms/app_container_dropdown.dart';
import '../widgets/shared/app_snackbar.dart';

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
        'barcode': widget.vinylData?.discogsId,
        'musicFormat': _selectedFormat,
      };

      if (widget.vinylData != null) {
        itemData['styles'] = widget.vinylData!.styles;
        itemData['format'] = widget.vinylData!.format;
        itemData['country'] = widget.vinylData!.country;
      }

      await itemRepo.addItem(
        householdId: _householdId,
        userId: authService.currentUserId!,
        itemData: itemData,
        photo: _photo,
      );

      if (mounted) {
        Navigator.pop(context);
        AppSnackbar.showSuccess(context, 'Vinyl added successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: $e');
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
          if (_isLoading)
            Center(
              child: Padding(
                padding: context.spacing.allMd,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveVinyl,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: context.spacing.allMd,
          children: [
            // Photo picker - clean and reusable
            AppPhotoPickerField(
              photo: _photo,
              onPhotoSelected: (photo) => setState(() => _photo = photo),
            ),
            context.spacing.gapLg,

            // Title field
            AppTextField(
              controller: _titleController,
              label: 'Title',
              prefixIcon: Icons.title,
              validator: (v) => v?.trim().isEmpty ?? true ? 'Title is required' : null,
            ),
            context.spacing.gapMd,

            // Artist field
            AppTextField(
              controller: _artistController,
              label: 'Artist',
              prefixIcon: Icons.person,
            ),
            context.spacing.gapMd,

            // Format dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedFormat,
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
            context.spacing.gapMd,

            // Label and Year row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: _labelController,
                    label: 'Label',
                    prefixIcon: Icons.business,
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
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
              ],
            ),
            context.spacing.gapMd,

            // Genre and Catalog Number row
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _genreController,
                    label: 'Genre',
                    prefixIcon: Icons.music_note,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _catalogController,
                    label: 'Catalog #',
                  ),
                ),
              ],
            ),
            context.spacing.gapMd,

            // Container dropdown - now clean and simple
            AppContainerDropdown(
              value: _selectedContainerId,
              onChanged: (v) => setState(() => _selectedContainerId = v),
            ),
            context.spacing.gapMd,

            // Notes field
            AppTextField(
              controller: _notesController,
              label: 'Notes (optional)',
              prefixIcon: Icons.note,
              maxLines: 4,
            ),
            context.spacing.gapLg,
          ],
        ),
      ),
    );
  }
}
