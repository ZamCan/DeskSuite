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

/// A document the user picked, with the name the picker reported.
typedef PickedDocument = ({Uint8List bytes, String name});

/// A picker for arbitrary documents. Kept separate from [FileGateway] so simple
/// image/project fakes in tests do not have to implement it.
abstract class DocumentPicker {
  Future<PickedDocument?> pickDocument();
}

class NativeFileGateway implements FileGateway, DocumentPicker {
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
    return _readBounded(file.readAsByteStream(), limit);
  }

  static Future<Uint8List> _readBounded(
    Stream<List<int>> stream,
    int limit,
  ) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in stream) {
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

  /// Opens a supported document and reports its name, because office format
  /// detection must not depend on the extension alone.
  @override
  Future<PickedDocument?> pickDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [
        'docx',
        'xlsx',
        'pptx',
        'odt',
        'ods',
        'odp',
        'rtf',
        'txt',
        'html',
        'htm',
        'pdf',
        'doc',
        'xls',
        'ppt',
      ],
    );
    if (file == null) return null;
    final bytes = await _readBounded(file.readAsByteStream(), 48 * 1024 * 1024);
    return (bytes: bytes, name: file.name);
  }

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
