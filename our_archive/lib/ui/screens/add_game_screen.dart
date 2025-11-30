import 'package:ionicons/ionicons.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';
import '../widgets/common/photo_picker_widget.dart';
import '../widgets/common/loading_button.dart';
import '../widgets/form/container_selector_field.dart';
import '../widgets/form/year_field.dart';
import '../widgets/form/notes_field.dart';

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
          const SnackBar(content: Text('Game added successfully!')),
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
        title: const Text('Add Game'),
        actions: [
          LoadingButton(
            isLoading: _isLoading,
            onPressed: _saveGame,
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

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter game title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Ionicons.text_outline),
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
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            PhotoPickerWidget(
              photo: _photo,
              onPhotoChanged: (photo) => setState(() => _photo = photo),
              placeholderIcon: Ionicons.game_controller_outline,
              placeholderText: 'Tap to add cover photo',
            ),
            const SizedBox(height: 16),

            // Game Details Section
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Text(
                'GAME DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            DropdownButtonFormField<String>(
              initialValue: _selectedPlatform,
              decoration: const InputDecoration(labelText: 'Platform', border: OutlineInputBorder(), prefixIcon: Icon(Ionicons.game_controller_outline)),
              items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _selectedPlatform = v),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(flex: 2, child: TextFormField(controller: _publisherController, decoration: const InputDecoration(labelText: 'Publisher', border: OutlineInputBorder(), prefixIcon: Icon(Ionicons.business_outline)), textCapitalization: TextCapitalization.words)),
              const SizedBox(width: 12),
              Expanded(child: YearField(controller: _yearController)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _genreController, decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder(), prefixIcon: Icon(Ionicons.apps_outline)), textCapitalization: TextCapitalization.words)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _playersController, decoration: const InputDecoration(labelText: 'Players', border: OutlineInputBorder(), prefixIcon: Icon(Ionicons.people_outline), hintText: '1-4'))),
            ]),
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

            ContainerSelectorField(
              selectedContainerId: _selectedContainerId,
              onChanged: (v) => setState(() => _selectedContainerId = v),
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

            NotesField(controller: _notesController),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
