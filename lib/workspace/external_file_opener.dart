import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// Opens supported external documents in an installed Android viewer/editor.
/// DeskSuite does not claim to edit Office formats internally through this path.
class ExternalFileOpener {
  ExternalFileOpener({MethodChannel? channel}) : _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel =
      MethodChannel('com.zamcan.desksuite/external_files');
  final MethodChannel _channel;

  static const int maxExternalFileBytes = 50 * 1024 * 1024;
  static const List<String> supportedExtensions = <String>[
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'odt', 'ods', 'odp', 'rtf', 'txt', 'html',
    'png', 'jpg', 'jpeg', 'webp',
  ];

  static String mimeTypeForName(String name) {
    final extension = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    return switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'odt' => 'application/vnd.oasis.opendocument.text',
      'ods' => 'application/vnd.oasis.opendocument.spreadsheet',
      'odp' => 'application/vnd.oasis.opendocument.presentation',
      'rtf' => 'application/rtf',
      'txt' => 'text/plain',
      'html' => 'text/html',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  Future<bool> pickAndOpen() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
    );
    if (file == null) return false;

    final knownLength = file.lengthSync();
    if (knownLength != null && knownLength > maxExternalFileBytes) {
      throw const FormatException('Choose a file smaller than 50 MB for external opening.');
    }

    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in file.readAsByteStream()) {
      length += chunk.length;
      if (length > maxExternalFileBytes) {
        throw const FormatException('Choose a file smaller than 50 MB for external opening.');
      }
      builder.add(chunk);
    }
    if (length == 0) throw const FormatException('The selected file is empty.');

    final bytes = builder.takeBytes();
    await _channel.invokeMethod<void>('openFile', <String, Object>{
      'name': file.name,
      'mimeType': mimeTypeForName(file.name),
      'bytes': Uint8List.fromList(bytes),
    });
    return true;
  }
}
