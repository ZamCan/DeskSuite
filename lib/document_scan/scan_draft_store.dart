import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import '../core/atomic_file_store.dart';
import '../core/ids.dart';
import '../images/photo_processor.dart';
import 'scan_pdf.dart';

const int maxScanDraftBytes = 64 * 1024 * 1024;

/// Immutable image content with private, opaque backing filenames. A page's
/// original is an orientation-baked PNG copy; the imported source is untouched.
class ScanDraftPage {
  ScanDraftPage({
    String? id,
    required this.original,
    required this.image,
    this.originalFile,
    this.imageFile,
  }) : id = id ?? newId();

  final String id;
  final PhotoResult original;
  final PhotoResult image;
  final String? originalFile, imageFile;

  ScanDraftPage withImage(PhotoResult value) => ScanDraftPage(
    id: id,
    original: original,
    image: value,
    originalFile: originalFile,
    imageFile: identical(value.bytes, original.bytes) ? originalFile : null,
  );
}

PhotoResult _inspectStoredPage(Uint8List bytes) {
  if (detectPhotoFormat(bytes) != PhotoFormat.png) {
    throw const FormatException('A saved scan page is not a PNG.');
  }
  final image = decodeBoundedPhoto(bytes, byteLimit: maxPhotoWorkingBytes);
  return PhotoResult(bytes, image.width, image.height);
}

/// A single recoverable local draft. Assets are written under new names first;
/// a small manifest is atomically replaced last. A failed save never makes a
/// partial new manifest visible. User-selected source files are never touched.
class ScanDraftStore {
  ScanDraftStore(this.root, {Future<void> Function(File, List<int>)? writeFile})
    : _writeFile = writeFile ?? replaceFileAtomically;
  final Directory root;
  final Future<void> Function(File, List<int>) _writeFile;
  Future<void> _tail = Future.value();
  File get _manifest => File('${root.path}${Platform.pathSeparator}draft.json');
  Directory get _assets =>
      Directory('${root.path}${Platform.pathSeparator}pages');

  File _asset(String name) {
    if (!name.endsWith('.png') ||
        !isSafeId(name.substring(0, name.length - 4))) {
      throw const FormatException('Invalid scan draft asset name.');
    }
    return File('${_assets.path}${Platform.pathSeparator}$name');
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final work = _tail.then<T>((_) => action());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<List<ScanDraftPage>> load() async {
    await _tail;
    await recoverAtomicBackup(_manifest);
    if (!await _manifest.exists()) return [];
    if (await _manifest.length() > 64 * 1024) {
      throw const FormatException('The scan draft manifest is too large.');
    }
    final data = jsonDecode(await _manifest.readAsString());
    if (data is! Map || data['version'] != 1 || data['pages'] is! List) {
      throw const FormatException('The scan draft manifest is invalid.');
    }
    final rows = data['pages'] as List;
    if (rows.length > maxScanPages) {
      throw const FormatException('The scan draft has too many pages.');
    }
    final pages = <ScanDraftPage>[];
    final ids = <String>{};
    var totalBytes = 0, totalPixels = 0;
    final imageCache = <String, PhotoResult>{};
    Future<PhotoResult> readImage(String name) async {
      final cached = imageCache[name];
      if (cached != null) return cached;
      final file = _asset(name);
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const FormatException('A scan draft page is missing.');
      }
      final length = await file.length();
      totalBytes += length;
      if (length < 1 ||
          length > maxPhotoWorkingBytes ||
          totalBytes > maxScanDraftBytes) {
        throw const FormatException(
          'A scan draft page exceeds the size limit.',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.length != length || bytes.length > maxPhotoWorkingBytes) {
        throw const FormatException('A scan draft page changed while reading.');
      }
      final image = await compute(_inspectStoredPage, bytes);
      imageCache[name] = image;
      return image;
    }

    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! String ||
          row['original'] is! String ||
          row['image'] is! String) {
        throw const FormatException('A scan draft page entry is invalid.');
      }
      final id = row['id'] as String;
      if (!isSafeId(id) || !ids.add(id)) {
        throw const FormatException('A scan draft page identifier is invalid.');
      }
      final originalName = row['original'] as String,
          imageName = row['image'] as String;
      final original = await readImage(originalName),
          image = await readImage(imageName);
      totalPixels += image.width * image.height;
      if (totalPixels > maxScanTotalPixels) {
        throw const FormatException('The scan draft exceeds the pixel limit.');
      }
      pages.add(
        ScanDraftPage(
          id: id,
          original: original,
          image: image,
          originalFile: originalName,
          imageFile: imageName,
        ),
      );
    }
    return pages;
  }

  /// Returns pages with committed asset names. The caller should use these for
  /// subsequent saves so unchanged assets do not need to be rewritten.
  Future<List<ScanDraftPage>> save(
    List<ScanDraftPage> input,
  ) => _enqueue(() async {
    if (input.length > maxScanPages) {
      throw const FormatException('A scan draft can have at most 8 pages.');
    }
    final ids = <String>{};
    var totalBytes = 0, totalPixels = 0;
    for (final page in input) {
      if (!isSafeId(page.id) || !ids.add(page.id)) {
        throw const FormatException('Invalid scan draft page identifier.');
      }
      for (final photo in [page.original, page.image]) {
        if (photo.bytes.isEmpty ||
            photo.bytes.length > maxPhotoWorkingBytes ||
            photo.width < 1 ||
            photo.height < 1 ||
            photo.width > maxPhotoSide ||
            photo.height > maxPhotoSide ||
            photo.width * photo.height > maxPhotoPixels ||
            detectPhotoFormat(photo.bytes) != PhotoFormat.png) {
          throw const FormatException('Invalid or oversized scan draft page.');
        }
        totalBytes += photo.bytes.length;
      }
      totalPixels += page.image.width * page.image.height;
    }
    if (totalBytes > maxScanDraftBytes || totalPixels > maxScanTotalPixels) {
      throw const FormatException(
        'The scan draft exceeds its storage or pixel limit.',
      );
    }
    await _assets.create(recursive: true);
    final committed = <ScanDraftPage>[];
    final used = <String>{};
    for (final page in input) {
      final originalName = page.originalFile ?? '${newId()}.png';
      final imageName = identical(page.original.bytes, page.image.bytes)
          ? originalName
          : page.imageFile ?? '${newId()}.png';
      final originalFile = _asset(originalName), imageFile = _asset(imageName);
      if (page.originalFile == null) {
        await _writeFile(originalFile, page.original.bytes);
      } else if (!await originalFile.exists()) {
        throw const FormatException('A saved scan original is missing.');
      }
      if (imageName != originalName && page.imageFile == null) {
        await _writeFile(imageFile, page.image.bytes);
      } else if (!await imageFile.exists()) {
        throw const FormatException('A saved scan page is missing.');
      }
      used.addAll([originalName, imageName]);
      committed.add(
        ScanDraftPage(
          id: page.id,
          original: page.original,
          image: page.image,
          originalFile: originalName,
          imageFile: imageName,
        ),
      );
    }
    final manifest = utf8.encode(
      jsonEncode({
        'version': 1,
        'pages': [
          for (final page in committed)
            {
              'id': page.id,
              'original': page.originalFile,
              'image': page.imageFile,
            },
        ],
      }),
    );
    await _writeFile(_manifest, manifest);
    // Cleanup is best-effort and only targets our own unreferenced assets
    // after the new manifest has been committed.
    try {
      await for (final entity in _assets.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('d_') &&
            name.endsWith('.png') &&
            isSafeId(name.substring(0, name.length - 4)) &&
            !used.contains(name)) {
          await entity.delete();
        }
      }
    } catch (_) {
      // The manifest remains valid; an orphan may be cleaned on a later save.
    }
    return committed;
  });

  /// Explicitly discards only this application's scan draft, after the UI has
  /// obtained confirmation. Does not touch imported or exported source files.
  Future<void> discard() => _enqueue(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
}
