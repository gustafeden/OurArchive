import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/extensions/context_ext.dart';
import '../../theme/app_radius.dart';

/// Reusable photo picker component
/// Eliminates ~200 lines of duplicate photo picker code across 5+ screens
class AppPhotoPickerField extends StatelessWidget {
  const AppPhotoPickerField({
    super.key,
    required this.photo,
    required this.onPhotoSelected,
    this.height = 200,
  });

  final File? photo;
  final Function(File?) onPhotoSelected;
  final double height;

  Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        onPhotoSelected(File(pickedFile.path));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showPhotoOptions(BuildContext context) {
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
                _pickPhoto(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(context, ImageSource.gallery);
              },
            ),
            if (photo != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  onPhotoSelected(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPhotoOptions(context),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.colors.photoPlaceholder,
          borderRadius: context.radius.mediumRadius,
          border: Border.all(color: context.colors.photoBorder),
        ),
        child: photo != null
            ? ClipRRect(
                borderRadius: context.radius.mediumRadius,
                child: Image.file(
                  photo!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 64,
                    color: context.colors.photoBorder,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add photo',
                    style: TextStyle(color: context.colors.secondaryText),
                  ),
                ],
              ),
      ),
    );
  }
}
