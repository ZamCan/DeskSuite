import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../images/photo_processor.dart';

/// Wraps one validated, orientation-baked optimized JPEG in an image-only A4
/// PDF. It does not add OCR or encryption and never modifies the source bytes.
Future<Uint8List> optimizedImagePdfInBackground(PhotoResult image) =>
    compute(optimizedImagePdf, image);

Future<Uint8List> optimizedImagePdf(PhotoResult image) async {
  if (image.width < 1 ||
      image.height < 1 ||
      image.width > maxPhotoSide ||
      image.height > maxPhotoSide ||
      image.width * image.height > maxPhotoPixels) {
    throw const FormatException('Invalid or oversized image dimensions.');
  }
  validateEncodedPhoto(
    image.bytes,
    image.width,
    image.height,
    PhotoFormat.jpeg,
  );
  final paper = image.width > image.height
      ? PdfPageFormat.a4.landscape
      : PdfPageFormat.a4.portrait;
  final document = pw.Document(compress: true);
  final embedded = pw.MemoryImage(image.bytes);
  document.addPage(
    pw.Page(
      pageFormat: paper,
      margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      build: (_) =>
          pw.Center(child: pw.Image(embedded, fit: pw.BoxFit.contain)),
    ),
  );
  final result = await document.save();
  if (result.length < 16 ||
      String.fromCharCodes(result.take(5)) != '%PDF-' ||
      !String.fromCharCodes(result.skip(result.length - 16))
          .contains('%%EOF')) {
    throw const FormatException(
      'The generated image PDF could not be validated.',
    );
  }
  return result;
}
