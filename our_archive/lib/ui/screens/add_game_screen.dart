import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../theme/extensions/context_ext.dart';
import '../widgets/forms/app_text_field.dart';
import '../widgets/forms/app_photo_picker_field.dart';
import '../widgets/forms/app_container_dropdown.dart';
import '../widgets/shared/app_snackbar.dart';

class AddGameScreen extends ConsumerStatefulWidget {
  final Household? household;
  final String? householdId; // Alternative to household object
  final String? preSelectedContainerId;

  const AddGameScreen({
    super.key,
    this.household,
    this.householdId,
    this.preSelectedContainerId,
  }) : assert(household != null || householdId != null,
            'Either household or householdId must be provided');

  @override
  ConsumerState<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends ConsumerState<AddGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _publisherController = TextEditingController();
  final _genreController = TextEditingController();
  final _playersController = TextEditingController();
  final _yearController = TextEditingController();
  final _notesController = TextEditingController();

  File? _photo;
  String? _selectedContainerId;
  String? _selectedPlatform;
  bool _isLoading = false;

  // Helper to get household ID from either household object or direct ID
  String get _householdId => widget.householdId ?? widget.household!.id;

  final List<String> _platforms = [
    'PlayStation',
    'PlayStation 2',
    'PlayStation 3',
    'PlayStation 4',
    'PlayStation 5',
    'Xbox',
    'Xbox 360',
    'Xbox One',
    'Xbox Series X|S',
    'Nintendo Switch',
    'Nintendo Wii',
    'Nintendo Wii U',
    'Nintendo 3DS',
    'Nintendo DS',
    'GameCube',
    'N64',
    'NES',
    'SNES',
    'PC',
    'Steam',
    'Mac',
    'Mobile (iOS)',
    'Mobile (Android)',
    'Sega Genesis',
    'Sega Dreamcast',
    'Atari',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedContainerId = widget.preSelectedContainerId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _publisherController.dispose();
    _genreController.dispose();
    _playersController.dispose();
    _yearController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveGame() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      final authService = ref.read(authServiceProvider);

      final itemData = {
        'title': _titleController.text.trim(),
        'type': 'game',
        'location': '',
        'quantity': 1,
        'tags': [],
        'archived': false,
        'sortOrder': 0,
        'containerId': _selectedContainerId,
        'platform': _selectedPlatform,
        'gamePublisher': _publisherController.text.trim().isEmpty ? null : _publisherController.text.trim(),
        'genre': _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        'players': _playersController.text.trim().isEmpty ? null : _playersController.text.trim(),
        'releaseYear': _yearController.text.trim().isEmpty ? null : _yearController.text.trim(),
        'description': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      await itemRepo.addItem(
        householdId: _householdId,
        userId: authService.currentUserId!,
        itemData: itemData,
        photo: _photo,
      );

      if (mounted) {
        Navigator.pop(context);
        AppSnackbar.showSuccess(context, 'Game added successfully!');
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
        title: const Text('Add Game'),
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
              onPressed: _saveGame,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: context.spacing.allMd,
          children: [
            // Photo picker - was 20 lines, now 1 component
            AppPhotoPickerField(
              photo: _photo,
              onPhotoSelected: (photo) => setState(() => _photo = photo),
            ),
            context.spacing.gapLg,

            // Title field - cleaner with AppTextField
            AppTextField(
              controller: _titleController,
              label: 'Title',
              prefixIcon: Icons.title,
              validator: (v) => v?.trim().isEmpty ?? true ? 'Title is required' : null,
            ),
            context.spacing.gapMd,

            // Platform dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedPlatform,
              decoration: const InputDecoration(
                labelText: 'Platform',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.videogame_asset),
              ),
              items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _selectedPlatform = v),
            ),
            context.spacing.gapMd,

            // Publisher and Year row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: _publisherController,
                    label: 'Publisher',
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

            // Genre and Players row
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _genreController,
                    label: 'Genre',
                    prefixIcon: Icons.category,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _playersController,
                    label: 'Players',
                    hint: '1-4',
                    prefixIcon: Icons.people,
                  ),
                ),
              ],
            ),
            context.spacing.gapMd,

            // Container dropdown - was complex .when() block, now 1 component
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
