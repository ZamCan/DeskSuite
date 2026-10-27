import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Isolates platform pickers from the editor and keeps imports size bounded.
abstract class FileGateway {
  Future<Uint8List?> pickImage();
  Future<Uint8List?> pickProject();
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  });
}

class NativeFileGateway implements FileGateway {
  Future<Uint8List?> _pick({
    required List<String> extensions,
    required int limit,
  }) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) return null;
    final knownLength = file.lengthSync();
    if (knownLength != null && knownLength > limit) {
      throw FormatException(
        'The selected file exceeds the ${limit ~/ (1024 * 1024)} MB limit.',
      );
    }
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in file.readAsByteStream()) {
      length += chunk.length;
      if (length > limit) {
        throw FormatException(
          'The selected file exceeds the ${limit ~/ (1024 * 1024)} MB limit.',
        );
      }
      builder.add(chunk);
    }
    if (length == 0) throw const FormatException('The selected file is empty.');
    return builder.takeBytes();
  }

  @override
  Future<Uint8List?> pickImage() =>
      _pick(extensions: ['png', 'jpg', 'jpeg', 'webp'], limit: 8 * 1024 * 1024);
  @override
  Future<Uint8List?> pickProject() =>
      _pick(extensions: ['dsdesign', 'dsproject'], limit: 32 * 1024 * 1024);
  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (name.isEmpty || name.contains('/') || name.contains('\\')) {
      throw const FormatException('Invalid export file name.');
    }
    return await FilePicker.saveFile(
          fileName: name,
          bytes: bytes,
          mimeType: mimeType,
        ) !=
        null;
  }
}
