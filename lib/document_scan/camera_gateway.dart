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

/// Implemented only by gateways that keep a private, recoverable capture.
/// The scan draft calls this after its page is committed, not merely read.
abstract interface class CommittedCaptureGateway {
  Future<void> acknowledgeCaptureSaved();

  /// Remove the private temporary original only after explicit confirmation.
  Future<bool> discardPendingCapture();
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
  if (total == 0 || total != length) {
    throw const FormatException('The captured image changed while being read.');
  }
  final bytes = builder.takeBytes();
  detectPhotoFormat(bytes);
  return bytes;
}

class AndroidCameraGateway implements CameraGateway, CommittedCaptureGateway {
  AndroidCameraGateway({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const MethodChannel _channel = MethodChannel(
    'com.zamcan.desksuite/document_camera',
  );

  final ImagePicker _picker;
  File? _pendingCapture;
  static final _captureName = RegExp(
    r'^(?:desksuite-capture-[A-Za-z0-9-]+\.jpg|desksuite-writing-[A-Za-z0-9-]+\.tmp)$',
  );

  @override
  Future<Uint8List?> capture() async {
    String? path;
    try {
      path = await _channel.invokeMethod<String>('capture');
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'camera_permission_denied':
          throw const FormatException(
            'Camera access is off. Allow it when prompted or enable Camera for DeskSuite in Android Settings. You can also import an image.',
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
    return _readRecoverableCapture(File(path));
  }

  @override
  Future<Uint8List?> retrieveLostCapture() async {
    // A complete native capture is renamed atomically in app-private cache.
    // A process may also stop between writing and renaming: attempt to salvage
    // a bounded, signature-recognized temporary file without claiming it is
    // complete. Keep originals until the scan draft commits or user discards.
    final temporary = await getTemporaryDirectory();
    final candidates = <(File, DateTime)>[];
    await for (final entity in temporary.list(followLinks: false)) {
      if (entity is File &&
          _captureName.hasMatch(entity.uri.pathSegments.last)) {
        try {
          candidates.add((entity, await entity.lastModified()));
        } on FileSystemException {
          // A vanished file is harmless; do not delete anything here.
        }
      }
    }
    candidates.sort((a, b) => b.$2.compareTo(a.$2));
    var hasUnreadableCapture = false;
    for (final candidate in candidates) {
      try {
        return await _readRecoverableCapture(candidate.$1);
      } on FormatException {
        hasUnreadableCapture = true;
      } on FileSystemException {
        hasUnreadableCapture = true;
      }
    }

    // Compatibility with a previous release interrupted while using
    // image_picker's external camera. This path is not used for new capture.
    final response = await _picker.retrieveLostData();
    if (!response.isEmpty) {
      if (response.exception != null) throw response.exception!;
      final images = response.files;
      if (images == null || images.isEmpty) {
        throw const FormatException(
          'The interrupted camera capture was unavailable.',
        );
      }
      return readCapturedImage(images.first);
    }
    if (hasUnreadableCapture) {
      throw const FormatException(
        'A private camera capture could not be read; it has not been erased.',
      );
    }
    return null;
  }

  Future<File> _verifiedPrivateCapture(File file) async {
    final temporary = await getTemporaryDirectory();
    if (!_captureName.hasMatch(file.uri.pathSegments.last) ||
        await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
      throw const FormatException(
        'The camera returned an invalid private capture.',
      );
    }
    final cacheRoot = await temporary.resolveSymbolicLinks();
    final resolved = await file.resolveSymbolicLinks();
    final safeFile = File(resolved);
    if (safeFile.parent.path != cacheRoot) {
      throw const FormatException(
        'The camera returned an invalid private capture.',
      );
    }
    return safeFile;
  }

  Future<Uint8List> _readRecoverableCapture(File file) async {
    final safeFile = await _verifiedPrivateCapture(file);
    final bytes = await readCapturedImage(XFile(safeFile.path));
    _pendingCapture = safeFile;
    return bytes;
  }

  @override
  Future<void> acknowledgeCaptureSaved() async {
    await discardPendingCapture();
  }

  @override
  Future<bool> discardPendingCapture() async {
    final pending = _pendingCapture;
    if (pending == null) return true;
    try {
      final safeFile = await _verifiedPrivateCapture(pending);
      await safeFile.delete();
      _pendingCapture = null;
      return true;
    } on FileSystemException {
      // Keep the private original for a later recovery rather than losing it.
      return false;
    } on FormatException {
      // Never delete a file if its private-path verification no longer passes.
      return false;
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
