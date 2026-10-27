import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/geometry.dart';
import '../images/photo_processor.dart';

class SheetPosition {
  const SheetPosition(this.leftMm, this.topMm);
  final double leftMm, topMm;
}

/// A single-page repeated photo layout, measured in millimetres.
class PhotoSheetSpec {
  PhotoSheetSpec({
    required this.pageWidthMm,
    required this.pageHeightMm,
    required this.photoWidthMm,
    required this.photoHeightMm,
    required this.marginMm,
    required this.spacingMm,
    required this.copies,
  }) {
    final values = [
      pageWidthMm,
      pageHeightMm,
      photoWidthMm,
      photoHeightMm,
      marginMm,
      spacingMm,
    ];
    if (!values.every((value) => value.isFinite) ||
        pageWidthMm < 50 ||
        pageHeightMm < 50 ||
        pageWidthMm > 1200 ||
        pageHeightMm > 1200 ||
        photoWidthMm < 5 ||
        photoHeightMm < 5 ||
        photoWidthMm > 250 ||
        photoHeightMm > 250 ||
        marginMm < 0 ||
        marginMm > 100 ||
        spacingMm < 0 ||
        spacingMm > 50 ||
        copies < 1 ||
        copies > 100) {
      throw const FormatException(
        'Invalid sheet dimensions, margins, spacing or copy count.',
      );
    }
  }
  final double pageWidthMm,
      pageHeightMm,
      photoWidthMm,
      photoHeightMm,
      marginMm,
      spacingMm;
  final int copies;

  int get columns {
    final usable = pageWidthMm - 2 * marginMm;
    return usable < photoWidthMm
        ? 0
        : ((usable + spacingMm) / (photoWidthMm + spacingMm)).floor();
  }

  int get rows {
    final usable = pageHeightMm - 2 * marginMm;
    return usable < photoHeightMm
        ? 0
        : ((usable + spacingMm) / (photoHeightMm + spacingMm)).floor();
  }

  int get capacity => columns * rows;
  List<SheetPosition> positions() {
    if (copies > capacity) {
      throw FormatException('Only $capacity photo(s) fit with these settings.');
    }
    return List.generate(
      copies,
      (index) => SheetPosition(
        marginMm + (index % columns) * (photoWidthMm + spacingMm),
        marginMm + (index ~/ columns) * (photoHeightMm + spacingMm),
      ),
    );
  }
}

class PhotoSheetRequest {
  const PhotoSheetRequest(this.imageBytes, this.spec);
  final Uint8List imageBytes;
  final PhotoSheetSpec spec;
}

Future<Uint8List> generatePhotoSheetInBackground(PhotoSheetRequest request) =>
    compute(generatePhotoSheet, request);

/// Embeds one validated PNG/JPEG in a physically sized, single-page PDF.
Future<Uint8List> generatePhotoSheet(PhotoSheetRequest request) async {
  if (request.imageBytes.isEmpty ||
      request.imageBytes.length > maxPhotoWorkingBytes) {
    throw const FormatException('Invalid or oversized photo.');
  }
  final spec = request.spec;
  final positions = spec.positions();
  final image = pw.MemoryImage(request.imageBytes);
  final widthPt = mmToPoints(spec.pageWidthMm);
  final heightPt = mmToPoints(spec.pageHeightMm);
  final pdf = pw.Document(compress: true);
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(widthPt, heightPt, marginAll: 0),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.SizedBox(
        width: widthPt,
        height: heightPt,
        child: pw.Stack(
          children: [
            for (final position in positions)
              pw.Positioned(
                left: mmToPoints(position.leftMm),
                top: mmToPoints(position.topMm),
                child: pw.SizedBox(
                  width: mmToPoints(spec.photoWidthMm),
                  height: mmToPoints(spec.photoHeightMm),
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  return pdf.save();
}
