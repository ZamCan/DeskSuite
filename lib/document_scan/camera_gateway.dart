import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../images/photo_processor.dart';

/// Platform boundary: tests inject a fake; Android capture is performed by a
/// DeskSuite-owned Camera2 screen, not by handing control to another app.
abstract class CameraGateway {
  Future<Uint8List?> capture();
  Future<Uint8List?> retrieveLostCapture();
}

/// Reject an image before allocating an unbounded byte buffer. This helper is
/// retained for recovery of captures created by older releases.
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
  AndroidCameraGateway({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const MethodChannel _channel = MethodChannel(
    'com.zamcan.desksuite/document_camera',
  );

  final ImagePicker _picker;

  @override
  Future<Uint8List?> capture() async {
    String? path;
    try {
      path = await _channel.invokeMethod<String>('capture');
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'camera_permission_denied':
          throw const FormatException(
            'Allow camera access to scan a document.',
          );
        case 'camera_unavailable':
          throw const FormatException(
            'This device camera is unavailable. Check permission and try again.',
          );
        case 'camera_busy':
          throw const FormatException(
            'A camera capture is already in progress.',
          );
        default:
          throw const FormatException(
            'The DeskSuite camera could not complete the capture. Try again.',
          );
      }
    }
    if (path == null) return null;
    return _readAndDeleteCapture(File(path));
  }

  @override
  Future<Uint8List?> retrieveLostCapture() async {
    // If Android recreated the app process while our camera Activity was open,
    // the Activity may have saved the JPEG before Flutter received its result.
    final temporary = await getTemporaryDirectory();
    final candidates = <File>[];
    await for (final entity in temporary.list(followLinks: false)) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith('desksuite-capture-')) {
        candidates.add(entity);
      }
    }
    candidates.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    if (candidates.isNotEmpty) {
      try {
        return await _readAndDeleteCapture(candidates.first);
      } on FormatException {
        // Delete the unusable capture and continue to legacy plugin recovery.
      }
    }

    // Backward compatibility for an app update interrupted during an older
    // image_picker camera hand-off.
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

  Future<Uint8List> _readAndDeleteCapture(File file) async {
    try {
      final length = await file.length();
      if (length < 1 || length > maxPhotoInputBytes) {
        throw const FormatException(
          'Camera image is empty or exceeds the 8 MB import limit.',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.length != length) {
        throw const FormatException('The captured image could not be read.');
      }
      detectPhotoFormat(bytes);
      return bytes;
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best effort cleanup; the capture remains private in app cache.
      }
    }
  }
}

class CameraRecovery {
  const CameraRecovery({this.bytes, this.failed = false});
  final Uint8List? bytes;
  final bool failed;
}

/// Called once at startup to recover a capture saved before Android recreated
/// the app process. Error details stay private; the caller receives a safe state.
Future<CameraRecovery> recoverCameraCapture(CameraGateway? gateway) async {
  if (gateway == null) return const CameraRecovery();
  try {
    return CameraRecovery(bytes: await gateway.retrieveLostCapture());
  } catch (_) {
    return const CameraRecovery(failed: true);
  }
}
