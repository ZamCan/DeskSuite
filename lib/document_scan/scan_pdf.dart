import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../images/photo_processor.dart';

const int maxScanPages = 8;
const int maxScanTotalBytes = 32 * 1024 * 1024;
const int maxScanTotalPixels = 24000000;

enum ScanPaper { a4, letter }

class ScanPdfRequest {
  const ScanPdfRequest(
    this.pages, {
    this.paper = ScanPaper.a4,
    this.autoRotatePaper = true,
  });

  /// Pages are orientation-baked PNGs produced by the scanning pipeline.
  final List<Uint8List> pages;
  final ScanPaper paper;
  final bool autoRotatePaper;
}

Future<Uint8List> createScanPdfInBackground(ScanPdfRequest request) =>
    compute(createScanPdf, request);

/// One contained image per physical page, in the supplied order. The output
/// is an image PDF: no OCR text or selectable/searchable text is claimed.
Future<Uint8List> createScanPdf(ScanPdfRequest request) async {
  if (request.pages.isEmpty || request.pages.length > maxScanPages) {
    throw const FormatException('Use between 1 and 8 pages per document.');
  }
  var totalBytes = 0;
  var totalPixels = 0;
  final document = pw.Document(compress: true);
  for (final bytes in request.pages) {
    totalBytes += bytes.length;
    if (totalBytes > maxScanTotalBytes) {
      throw const FormatException(
        'Document pages exceed the 32 MB working limit.',
      );
    }
    if (detectPhotoFormat(bytes) != PhotoFormat.png) {
      throw const FormatException(
        'Document pages must be normalized PNG images.',
      );
    }
    final decoded = decodeBoundedPhoto(bytes, byteLimit: maxPhotoWorkingBytes);
    totalPixels += decoded.width * decoded.height;
    if (totalPixels > maxScanTotalPixels) {
      throw const FormatException(
        'Document exceeds the 24-megapixel total limit.',
      );
    }
    final base = request.paper == ScanPaper.a4
        ? PdfPageFormat.a4
        : PdfPageFormat.letter;
    final paper = request.autoRotatePaper && decoded.width > decoded.height
        ? base.landscape
        : base.portrait;
    final image = pw.MemoryImage(bytes);
    document.addPage(
      pw.Page(
        pageFormat: paper,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  final result = await document.save();
  if (result.length < 16 ||
      String.fromCharCodes(result.take(5)) != '%PDF-' ||
      !String.fromCharCodes(result.skip(result.length - 16))
          .contains('%%EOF')) {
    throw const FormatException('The generated PDF could not be validated.');
  }
  return result;
}
