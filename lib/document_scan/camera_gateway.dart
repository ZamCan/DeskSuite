import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../images/photo_processor.dart';

/// Platform boundary: tests inject a fake; the Android implementation delegates
/// capture to the device's installed camera application.
abstract class CameraGateway {
  Future<Uint8List?> capture();
  Future<Uint8List?> retrieveLostCapture();
}

/// Reject a camera result before allocating an unbounded byte buffer. The
/// platform camera/plugin may have staged the result in its own cache first.
Future<Uint8List> readCapturedImage(XFile file) async {
  final length = await file.length();
  if (length < 1 || length > maxPhotoInputBytes) {
    throw const FormatException(
      'Camera image is empty or exceeds the 8 MB import limit.',
    );
  }
  final builder = BytesBuilder(copy: false);
  var total = 0;
  await for (final chunk in file.openRead()) {
    total += chunk.length;
    if (total > maxPhotoInputBytes) {
      throw const FormatException(
        'Camera image exceeds the 8 MB import limit.',
      );
    }
    builder.add(chunk);
  }
  if (total == 0) throw const FormatException('Camera image is empty.');
  final bytes = builder.takeBytes();
  detectPhotoFormat(bytes);
  return bytes;
}

class AndroidCameraGateway implements CameraGateway {
  AndroidCameraGateway({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<Uint8List?> capture() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );
    return image == null ? null : readCapturedImage(image);
  }

  @override
  Future<Uint8List?> retrieveLostCapture() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) throw response.exception!;
    final images = response.files;
    if (images == null || images.isEmpty) {
      throw const FormatException(
        'The interrupted camera capture was unavailable.',
      );
    }
    return readCapturedImage(images.first);
  }
}

class CameraRecovery {
  const CameraRecovery({this.bytes, this.failed = false});
  final Uint8List? bytes;
  final bool failed;
}

/// Called once at Android startup, because the OS can kill an activity while
/// the external camera is open. Never logs the capture or its private path.
Future<CameraRecovery> recoverCameraCapture(CameraGateway? gateway) async {
  if (gateway == null) return const CameraRecovery();
  try {
    return CameraRecovery(bytes: await gateway.retrieveLostCapture());
  } catch (_) {
    return const CameraRecovery(failed: true);
  }
}
