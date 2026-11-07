import 'dart:io';

import 'package:image_picker/image_picker.dart' as picker;

/// Picks a photo from the camera or the gallery. Wraps `image_picker` so
/// tests can supply a fake instead of touching real device hardware.
abstract interface class PhotoPicker {
  Future<File?> pickFromCamera();
  Future<File?> pickFromGallery();
}

class DevicePhotoPicker implements PhotoPicker {
  final _picker = picker.ImagePicker();

  @override
  Future<File?> pickFromCamera() async {
    final file = await _picker.pickImage(source: picker.ImageSource.camera);
    return file == null ? null : File(file.path);
  }

  @override
  Future<File?> pickFromGallery() async {
    final file = await _picker.pickImage(source: picker.ImageSource.gallery);
    return file == null ? null : File(file.path);
  }
}
