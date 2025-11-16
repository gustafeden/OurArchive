import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/providers.dart';
import '../../data/models/household.dart';

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

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _photo = File(pickedFile.path));
    }
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
        Navigator.popUntil(context, (route) => route.isFirst);
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
    final containersAsync = ref.watch(allContainersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Game'),
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _saveGame),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Wrap(children: [
                    ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'), onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); }),
                    ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); }),
                    if (_photo != null) ListTile(leading: const Icon(Icons.delete), title: const Text('Remove Photo'), onTap: () { Navigator.pop(context); setState(() => _photo = null); }),
                  ]),
                ),
              ),
              child: Container(
                height: 200,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[400]!)),
                child: _photo != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_photo!, fit: BoxFit.cover))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sports_esports, size: 64, color: Colors.grey), SizedBox(height: 8), Text('Tap to add cover photo', style: TextStyle(color: Colors.grey))]),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title)), validator: (v) => v?.trim().isEmpty ?? true ? 'Title is required' : null, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPlatform,
              decoration: const InputDecoration(labelText: 'Platform', border: OutlineInputBorder(), prefixIcon: Icon(Icons.videogame_asset)),
              items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _selectedPlatform = v),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(flex: 2, child: TextFormField(controller: _publisherController, decoration: const InputDecoration(labelText: 'Publisher', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)), textCapitalization: TextCapitalization.words)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _yearController, decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()), keyboardType: TextInputType.number, maxLength: 4, buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _genreController, decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)), textCapitalization: TextCapitalization.words)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _playersController, decoration: const InputDecoration(labelText: 'Players', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people), hintText: '1-4'))),
            ]),
            const SizedBox(height: 16),
            containersAsync.when(
              data: (containers) => DropdownButtonFormField<String>(
                value: _selectedContainerId,
                decoration: const InputDecoration(labelText: 'Container (optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.place)),
                items: [const DropdownMenuItem<String>(value: null, child: Text('No container')), ...containers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))],
                onChanged: (v) => setState(() => _selectedContainerId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load containers'),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note), alignLabelWithHint: true), maxLines: 4, textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
