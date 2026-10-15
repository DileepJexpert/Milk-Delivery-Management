import 'dart:convert';

import 'package:image_picker/image_picker.dart';

/// Captures a JPEG via the device camera (or gallery), downsizes it, and
/// returns a base64 string ready to persist on a DailyDelivery row.
/// Returns null if the user cancels.
class ProofPhoto {
  static final _picker = ImagePicker();

  static Future<String?> capture() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 60,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  static Future<String?> pickFromGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 60,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
}
