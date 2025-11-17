import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Mixin providing OCR (Optical Character Recognition) functionality
/// for scanner screens.
///
/// This mixin reduces code duplication by centralizing:
/// - Photo capture from camera
/// - Text recognition using ML Kit
/// - Error handling for OCR operations
/// - Resource disposal
///
/// Usage example:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with OcrMixin {
///
///   Future<void> _handlePhotoSearch() async {
///     final text = await captureAndRecognizeText();
///     if (text != null) {
///       // Use extracted text for search
///     }
///   }
/// }
/// ```
mixin OcrMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  // Lazy initialization - only created when OCR is actually used
  late final TextRecognizer _textRecognizer = TextRecognizer();

  /// Capture a photo and extract text using OCR
  ///
  /// Returns the extracted text if successful, null otherwise
  /// Shows error messages to user via SnackBar
  Future<String?> captureAndRecognizeText() async {
    try {
      // Pick image from camera (create ImagePicker locally, no need to store)
      final imagePicker = ImagePicker();
      final XFile? photo = await imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo == null) return null;

      // Perform OCR on the image
      final inputImage = InputImage.fromFilePath(photo.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (!mounted) return null;

      // Extract and trim text
      final extractedText = recognizedText.text.trim();

      if (extractedText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No text found in image. Try again with better lighting.'),
            ),
          );
        }
        return null;
      }

      return extractedText;
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recognizing text: ${e.toString()}'),
        ),
      );
      return null;
    }
  }

  /// Dispose of OCR resources
  /// Call this in dispose() of the implementing widget
  void disposeOcr() {
    _textRecognizer.close();
  }
}
