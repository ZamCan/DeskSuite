import 'dart:typed_data';

import 'package:pdf_document/pdf_document.dart';

/// What DeskSuite can prove about a PDF before offering to edit it.
///
/// Everything here is read from the document itself by the same engine that
/// renders and edits it, so the page count, the encryption state and the page
/// sizes in the UI are the engine's, not a guess from the file name.
class PdfInspection {
  const PdfInspection({
    required this.pageCount,
    required this.byteLength,
    required this.isEncrypted,
    required this.firstPageWidthPt,
    required this.firstPageHeightPt,
  });

  final int pageCount;
  final int byteLength;
  final bool isEncrypted;

  /// First page size in points (1/72 inch). Zero when the engine reports none.
  final double firstPageWidthPt;
  final double firstPageHeightPt;

  double get firstPageWidthMm => firstPageWidthPt / 72 * 25.4;
  double get firstPageHeightMm => firstPageHeightPt / 72 * 25.4;

  String get sizeLabel {
    if (byteLength < 1024) return '$byteLength B';
    if (byteLength < 1024 * 1024) {
      return '${(byteLength / 1024).toStringAsFixed(1)} kB';
    }
    return '${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get pageSizeLabel {
    if (firstPageWidthPt <= 0 || firstPageHeightPt <= 0) {
      return 'Page size not reported';
    }
    return '${firstPageWidthMm.toStringAsFixed(0)} × '
        '${firstPageHeightMm.toStringAsFixed(0)} mm';
  }
}

/// Raised with a message a user can act on, never with a raw parser trace.
class PdfOpenFailure implements Exception {
  const PdfOpenFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// True when `%PDF-` appears where the format allows it: anywhere in the first
/// 1024 bytes, because producers may put a short preamble first.
bool looksLikePdf(Uint8List bytes) {
  if (bytes.length < 5) return false;
  final last = bytes.length < 1029 ? bytes.length - 5 : 1024;
  for (var offset = 0; offset <= last; offset++) {
    if (bytes[offset] == 0x25 &&
        bytes[offset + 1] == 0x50 &&
        bytes[offset + 2] == 0x44 &&
        bytes[offset + 3] == 0x46 &&
        bytes[offset + 4] == 0x2D) {
      return true;
    }
  }
  return false;
}

/// Largest PDF DeskSuite will parse in memory on a phone.
const int maxPdfBytes = 96 * 1024 * 1024;

/// Reads page count, size and encryption state, or throws [PdfOpenFailure] with
/// a specific reason. The bytes are not modified.
PdfInspection inspectPdf(Uint8List bytes, {String password = ''}) {
  if (bytes.isEmpty) {
    throw const PdfOpenFailure('That file is empty.');
  }
  if (bytes.length > maxPdfBytes) {
    throw PdfOpenFailure(
      'That PDF is ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB. '
      'DeskSuite opens PDFs up to ${maxPdfBytes ~/ (1024 * 1024)} MB on a phone.',
    );
  }
  if (!looksLikePdf(bytes)) {
    throw const PdfOpenFailure(
      'That file is not a PDF. Images, office documents and text belong in '
      'Document converter or Text extraction.',
    );
  }
  final PdfDocument document;
  try {
    document = PdfDocument.open(bytes, password: password);
  } catch (error) {
    final message = '$error';
    if (message.toLowerCase().contains('password')) {
      throw const PdfOpenFailure(
        'This PDF is password-protected. Password unlocking is not available '
        'yet, so DeskSuite will not pretend it opened the file.',
      );
    }
    throw const PdfOpenFailure(
      'This PDF could not be read. It may be damaged or use a feature the '
      'reader does not support. Your original file has not been changed.',
    );
  }
  final count = document.pageCount;
  if (count < 1) {
    throw const PdfOpenFailure(
      'This PDF has no pages to show. Your original file has not been changed.',
    );
  }
  var widthPt = 0.0;
  var heightPt = 0.0;
  try {
    final box = document.page(0).cropBox;
    widthPt = box.width;
    heightPt = box.height;
  } catch (_) {
    // A page with an unusual box is still a page; the size label says so.
  }
  return PdfInspection(
    pageCount: count,
    byteLength: bytes.length,
    isEncrypted: document.cos.isEncrypted,
    firstPageWidthPt: widthPt,
    firstPageHeightPt: heightPt,
  );
}

/// A file name derived from the picked name: no directories, no traversal, no
/// characters that break Android's file names, and never empty.
String pdfBaseName(String name) {
  final leaf = name.split(RegExp(r"[/\\]")).last;
  final dot = leaf.lastIndexOf('.');
  final value = dot > 0 ? leaf.substring(0, dot) : leaf;
  final safe = value
      // Anything that is not a letter, digit, space, underscore or hyphen
      // becomes a hyphen, so a name can never escape the export directory.
      .replaceAll(RegExp(r'[^A-Za-z0-9 _-]+'), '-')
      .trim()
      // Collapse runs of separators so "a  b--c" does not become "a--b--c".
      .replaceAll(RegExp(r'[\s_-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (safe.isEmpty) return 'document';
  return safe.length > 60 ? safe.substring(0, 60) : safe;
}
