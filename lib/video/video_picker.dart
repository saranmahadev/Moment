import 'dart:io';

import 'package:image_picker/image_picker.dart' as picker;

/// Records a video with the camera or picks one from the gallery. Wraps
/// `image_picker` so tests can supply a fake instead of device hardware.
abstract interface class VideoPicker {
  Future<File?> recordWithCamera();
  Future<File?> pickFromGallery();
}

class DeviceVideoPicker implements VideoPicker {
  final _picker = picker.ImagePicker();

  @override
  Future<File?> recordWithCamera() async {
    final file = await _picker.pickVideo(source: picker.ImageSource.camera);
    return file == null ? null : File(file.path);
  }

  @override
  Future<File?> pickFromGallery() async {
    final file = await _picker.pickVideo(source: picker.ImageSource.gallery);
    return file == null ? null : File(file.path);
  }
}
