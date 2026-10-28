import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../core/file_limits.dart';
import 'office_zip_guard.dart';

/// Bounded reader for ZIP-based office packages (OOXML and ODF).
///
/// Office files are attacker-controlled input: the reader caps the archive size,
/// the number of entries, each entry's uncompressed size and the total
/// uncompressed bytes so a compression bomb cannot exhaust memory.
/// Documented resource limits for office package reading.
abstract final class OfficePackageLimits {
  static const int maxArchiveBytes = maxDocumentBytes;
  static const int maxEntryBytes = 24 * 1024 * 1024;
  static const int maxTotalBytes = 64 * 1024 * 1024;
  static const int maxEntries = 4000;
}

class OfficePackage {
  OfficePackage._(this._files, this.totalBytes);

  static const int maxArchiveBytes = OfficePackageLimits.maxArchiveBytes;
  static const int maxEntryBytes = OfficePackageLimits.maxEntryBytes;
  static const int maxTotalBytes = OfficePackageLimits.maxTotalBytes;
  static const int maxEntries = OfficePackageLimits.maxEntries;

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
    // Preflight central-directory declarations before the ZIP library inflates
    // any entry. This rejects ZIP64, encrypted/multi-disk packages, duplicate
    // names, symlinks, overlapping payloads and declared expansion bombs.
    final guardedEntries = guardOfficeZip(
      bytes,
      maxEntries: maxEntries,
      maxEntryBytes: maxEntryBytes,
      maxTotalBytes: maxTotalBytes,
    );
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (error) {
      throw const FormatException(
        'The document package is damaged or not a valid ZIP container.',
      );
    }
    final files = <String, Uint8List>{};
    var total = 0;
    var count = 0;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      count++;
      if (count > maxEntries) {
        throw const FormatException('The document contains too many parts.');
      }
      final content = entry.readBytes();
      if (content == null) {
        throw const FormatException('A document part could not be read.');
      }
      final guarded = guardedEntries[entry.name];
      if (guarded == null ||
          content.length != guarded.size ||
          officeZipCrc32(content) != guarded.crc32) {
        throw FormatException(
          'The document part "${entry.name}" failed integrity validation.',
        );
      }
      if (entry.size > maxEntryBytes) {
        throw FormatException(
          'The document part "${entry.name}" is too large.',
        );
      }
      total += content.length;
      if (total > maxTotalBytes) {
        throw const FormatException(
          'The document expands beyond the 64 MB processing limit.',
        );
      }
      files[entry.name] = content;
    }
    if (files.isEmpty) {
      throw const FormatException('The document package contains no parts.');
    }
    return OfficePackage._(files, total);
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
