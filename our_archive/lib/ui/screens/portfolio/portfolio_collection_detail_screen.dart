import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/portfolio_providers.dart';
import '../../../data/models/portfolio_collection.dart';
import '../../../data/models/portfolio_photo.dart';
import '../../services/ui_service.dart';
import 'portfolio_photo_edit_screen.dart';

class PortfolioCollectionDetailScreen extends ConsumerStatefulWidget {
  final PortfolioCollection collection;

  const PortfolioCollectionDetailScreen({
    super.key,
    required this.collection,
  });

  @override
  ConsumerState<PortfolioCollectionDetailScreen> createState() =>
      _PortfolioCollectionDetailScreenState();
}

class _PortfolioCollectionDetailScreenState
    extends ConsumerState<PortfolioCollectionDetailScreen> {
  bool _isUploading = false;
  int _uploadCount = 0;
  int _uploadTotal = 0;

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(portfolioPhotosProvider(widget.collection.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.title),
        actions: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _uploadTotal > 0 ? _uploadCount / _uploadTotal : null,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Ionicons.cloud_upload_outline),
              onPressed: () => _showUploadOptions(context),
            ),
        ],
      ),
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Ionicons.alert_circle_outline,
                  size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .invalidate(portfolioPhotosProvider(widget.collection.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Ionicons.camera_outline,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No photos yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload photos to this collection',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showUploadOptions(context),
                    icon: const Icon(Ionicons.cloud_upload_outline),
                    label: const Text('Upload Photos'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Upload progress banner
              if (_isUploading)
                Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text('Uploading $_uploadCount of $_uploadTotal...'),
                    ],
                  ),
                ),

              // Photo count header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '${photos.length} ${photos.length == 1 ? 'photo' : 'photos'}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      'Drag to reorder',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              ),

              // Photos grid
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: photos.length,
                  onReorder: (oldIndex, newIndex) =>
                      _onReorder(photos, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return _PhotoCard(
                      key: ValueKey(photo.id),
                      photo: photo,
                      index: index,
                      onTap: () => _openPhotoEditor(context, photo),
                      onSetAsCover: () => _setAsCover(photo),
                      onDelete: () => _showDeleteConfirmation(context, photo),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Ionicons.camera_outline),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Ionicons.images_outline),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select multiple photos'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();

    try {
      List<XFile> files = [];

      if (source == ImageSource.camera) {
        final file = await picker.pickImage(source: source);
        if (file != null) files = [file];
      } else {
        files = await picker.pickMultiImage();
      }

      if (files.isEmpty) return;

      setState(() {
        _isUploading = true;
        _uploadCount = 0;
        _uploadTotal = files.length;
      });

      final repository = ref.read(portfolioRepositoryProvider);

      for (final file in files) {
        try {
          await repository.uploadPhoto(
            collectionId: widget.collection.id,
            collectionSlug: widget.collection.slug,
            imageFile: File(file.path),
          );

          setState(() {
            _uploadCount++;
          });
        } catch (e) {
          UiService.showError('Failed to upload ${file.name}: $e');
        }
      }

      UiService.showSuccess(
          'Uploaded ${files.length} ${files.length == 1 ? 'photo' : 'photos'}');
    } catch (e) {
      UiService.showError('Error: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadCount = 0;
        _uploadTotal = 0;
      });
    }
  }

  void _openPhotoEditor(BuildContext context, PortfolioPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PortfolioPhotoEditScreen(photo: photo),
      ),
    );
  }

  Future<void> _setAsCover(PortfolioPhoto photo) async {
    try {
      final repository = ref.read(portfolioRepositoryProvider);
      await repository.setCollectionCover(
        widget.collection.id,
        widget.collection.slug,
        photo.src,
      );
      UiService.showSuccess('Cover updated');
    } catch (e) {
      UiService.showError('Error: $e');
    }
  }

  void _showDeleteConfirmation(BuildContext context, PortfolioPhoto photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text(
          'This will permanently delete this photo. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final repository = ref.read(portfolioRepositoryProvider);
                await repository.deletePhoto(photo.id);
                UiService.showSuccess('Photo deleted');
              } catch (e) {
                UiService.showError('Error: $e');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _onReorder(
      List<PortfolioPhoto> photos, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final reordered = List<PortfolioPhoto>.from(photos);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    try {
      final repository = ref.read(portfolioRepositoryProvider);
      await repository.reorderPhotos(reordered);
    } catch (e) {
      UiService.showError('Error reordering: $e');
    }
  }
}

class _PhotoCard extends StatelessWidget {
  final PortfolioPhoto photo;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onSetAsCover;
  final VoidCallback onDelete;

  const _PhotoCard({
    super.key,
    required this.photo,
    required this.index,
    required this.onTap,
    required this.onSetAsCover,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Photo thumbnail
            SizedBox(
              width: 100,
              height: 100,
              child: CachedNetworkImage(
                imageUrl: photo.src,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Ionicons.image_outline),
                ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Caption or placeholder
                    Text(
                      photo.caption ?? 'No caption',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: photo.caption == null
                                ? Colors.grey[400]
                                : null,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Location
                    if (photo.location != null)
                      Row(
                        children: [
                          Icon(Ionicons.location_outline,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              photo.location!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 4),

                    // EXIF summary
                    if (photo.exif != null && !photo.exif!.isEmpty)
                      Row(
                        children: [
                          Icon(Ionicons.aperture_outline,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              photo.exif!.toDisplayString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Colors.grey[500]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    // Show EXIF toggle indicator
                    if (!photo.showExif)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'EXIF hidden',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Ionicons.ellipsis_vertical_outline),
              onSelected: (value) {
                switch (value) {
                  case 'cover':
                    onSetAsCover();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'cover',
                  child: Row(
                    children: [
                      Icon(Ionicons.star_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Set as Cover'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Ionicons.trash_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
