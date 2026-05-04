import 'package:image_picker/image_picker.dart';

import 'file_service.dart';

class CameraService {
  CameraService({
    ImagePicker? picker,
  }) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<NovaAttachment?> capturePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 92,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return NovaAttachment(
      name: picked.name.trim().isEmpty ? 'camera.jpg' : picked.name.trim(),
      mimeType: 'image/jpeg',
      bytes: bytes,
      localPath: picked.path,
      fromCamera: true,
    );
  }
}
