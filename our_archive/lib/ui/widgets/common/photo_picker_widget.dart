import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Reusable photo picker widget that displays a photo container
/// with tap-to-select functionality and camera/gallery options.
class PhotoPickerWidget extends StatelessWidget {
  final File? photo;
  final ValueChanged<File?> onPhotoChanged;
  final double height;
  final IconData placeholderIcon;
  final String placeholderText;

  const PhotoPickerWidget({
    super.key,
    required this.photo,
    required this.onPhotoChanged,
    this.height = 200,
    this.placeholderIcon = Icons.add_photo_alternate,
    this.placeholderText = 'Tap to add photo',
  });

  Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      onPhotoChanged(File(pickedFile.path));
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
                  onPhotoChanged(null);
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
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: photo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  photo!,
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(placeholderIcon, size: 64, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    placeholderText,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }
}
