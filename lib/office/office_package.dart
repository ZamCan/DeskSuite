import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'office_zip_guard.dart';

/// Bounded reader for ZIP-based office packages (OOXML and ODF).
///
/// Office files are attacker-controlled input: the reader caps the archive size,
/// the number of entries, each entry's uncompressed size and the total
/// uncompressed bytes so a compression bomb cannot exhaust memory.
/// Documented resource limits for office package reading.
abstract final class OfficePackageLimits {
  static const int maxArchiveBytes = 48 * 1024 * 1024;
  static const int maxEntryBytes = 24 * 1024 * 1024;
  static const int maxTotalBytes = 64 * 1024 * 1024;
  static const int maxEntries = 4000;
}

class OfficePackage {
  OfficePackage._(this._files, this.totalBytes);

  static const int maxArchiveBytes = OfficePackageLimits.maxArchiveBytes;
  static const int maxEntryBytes = 24 * 1024 * 1024;
  static const int maxTotalBytes = 64 * 1024 * 1024;
  static const int maxEntries = 4000;

  final Map<String, Uint8List> _files;
  final int totalBytes;

  int get entryCount => _files.length;
  Iterable<String> get names => _files.keys;

  bool contains(String name) => _files.containsKey(name);

  static OfficePackage open(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('The document is empty.');
    }
    if (bytes.length > maxArchiveBytes) {
      throw const FormatException(
        'The document exceeds the 48 MB import limit.',
      );
    }
    // ZipDecoder 4.5.2 can inflate a symlink before exposing it to callers,
    // and its `verify` parameter does not verify CRCs. Check the directory,
    // limits, names and local headers before decoding; then check every CRC
    // explicitly after the library's bounded per-entry decompression.
    final metadata = guardOfficeZip(
      bytes,
      maxEntries: maxEntries,
      maxEntryBytes: maxEntryBytes,
      maxTotalBytes: maxTotalBytes,
    );
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final files = <String, Uint8List>{};
      var total = 0;
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        final expected = metadata[entry.name];
        if (expected == null || entry.size != expected.size) {
          throw const FormatException('Inconsistent document package parts.');
        }
        final content = entry.readBytes();
        if (content == null ||
            content.length != expected.size ||
            getCrc32(content) != expected.crc32) {
          throw const FormatException('A document part is damaged.');
        }
        total += content.length;
        files[entry.name] = content;
      }
      if (files.isEmpty) {
        throw const FormatException('The document package contains no parts.');
      }
      return OfficePackage._(files, total);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw const FormatException(
        'The document package is damaged or not a valid ZIP container.',
      );
    }
  }

  Uint8List bytesOf(String name) {
    final data = _files[name];
    if (data == null) {
      throw FormatException('The document is missing its "$name" part.');
    }
    return data;
  }

  String? textOf(String name) {
    final data = _files[name];
    if (data == null) return null;
    try {
      return utf8.decode(data);
    } on FormatException {
      return null;
    }
  }

  /// Resolves a relationship target relative to a source part.
  String resolve({required String from, required String target}) {
    if (target.startsWith('/')) return target.substring(1);
    final base = from.contains('/')
        ? from.substring(0, from.lastIndexOf('/') + 1)
        : '';
    final segments = <String>[];
    for (final segment in '$base$target'.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (segments.isNotEmpty) segments.removeLast();
        continue;
      }
      segments.add(segment);
    }
    return segments.join('/');
  }
}
