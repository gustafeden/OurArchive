import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/portfolio_providers.dart';
import '../../../data/models/portfolio_photo.dart';
import '../../services/ui_service.dart';

class PortfolioPhotoEditScreen extends ConsumerStatefulWidget {
  final PortfolioPhoto photo;

  const PortfolioPhotoEditScreen({
    super.key,
    required this.photo,
  });

  @override
  ConsumerState<PortfolioPhotoEditScreen> createState() =>
      _PortfolioPhotoEditScreenState();
}

class _PortfolioPhotoEditScreenState
    extends ConsumerState<PortfolioPhotoEditScreen> {
  late TextEditingController _captionController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  late bool _showExif;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.photo.caption ?? '');
    _locationController =
        TextEditingController(text: widget.photo.location ?? '');
    _notesController = TextEditingController(text: widget.photo.notes ?? '');
    _showExif = widget.photo.showExif;

    _captionController.addListener(_onChanged);
    _locationController.addListener(_onChanged);
    _notesController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final hasChanges = _captionController.text != (widget.photo.caption ?? '') ||
        _locationController.text != (widget.photo.location ?? '') ||
        _notesController.text != (widget.photo.notes ?? '') ||
        _showExif != widget.photo.showExif;

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Photo'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_hasChanges)
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo preview
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.photo.src,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Ionicons.image_outline, size: 48),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Caption field
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'Add a caption for this photo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Ionicons.text_outline),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 16),

            // Location field
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Where was this taken?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Ionicons.location_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Add any additional notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Ionicons.document_text_outline),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 24),

            // EXIF section
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle
                  SwitchListTile(
                    title: const Text('Show EXIF on website'),
                    subtitle: const Text(
                        'Display camera settings with this photo'),
                    value: _showExif,
                    onChanged: (value) {
                      setState(() {
                        _showExif = value;
                        _onChanged();
                      });
                    },
                  ),

                  const Divider(height: 1),

                  // EXIF data display
                  if (widget.photo.exif != null && !widget.photo.exif!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXIF Data',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildExifRow(
                              Ionicons.camera_outline,
                              'Camera',
                              widget.photo.exif!.camera),
                          _buildExifRow(
                              Ionicons.disc_outline,
                              'Lens',
                              widget.photo.exif!.lens),
                          _buildExifRow(
                              Ionicons.aperture_outline,
                              'Aperture',
                              widget.photo.exif!.aperture),
                          _buildExifRow(
                              Ionicons.timer_outline,
                              'Shutter',
                              widget.photo.exif!.shutter),
                          _buildExifRow(
                              Ionicons.speedometer_outline,
                              'ISO',
                              widget.photo.exif!.iso?.toString()),
                          _buildExifRow(
                              Ionicons.resize_outline,
                              'Focal Length',
                              widget.photo.exif!.focalLength),
                          _buildExifRow(
                              Ionicons.calendar_outline,
                              'Date',
                              widget.photo.exif!.date),
                        ],
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No EXIF data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExifRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(portfolioRepositoryProvider);
      final updated = widget.photo.copyWith(
        caption:
            _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes:
            _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        showExif: _showExif,
      );

      await repository.updatePhoto(updated);

      if (mounted) {
        UiService.showSuccess('Photo updated');
        Navigator.pop(context);
      }
    } catch (e) {
      UiService.showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
