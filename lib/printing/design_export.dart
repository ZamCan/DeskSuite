import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/design_document.dart';
import '../design/design_renderer.dart';
import '../design/geometry.dart';
import 'raster_budget.dart' as raster;

// Compatibility aliases for existing callers; the limits live in one engine.
const int maxExportPixels = raster.maxExportPixels;
const int maxExportSide = raster.maxExportSide;

class ExportDimensions {
  const ExportDimensions(this.width, this.height);
  final int width;
  final int height;
}

ExportDimensions exportDimensions(DesignDocument doc, int dpi) {
  final bounded = raster.boundedRasterDimensions(
    doc.widthMm,
    doc.heightMm,
    dpi,
  );
  return ExportDimensions(bounded.width, bounded.height);
}

/// Effective source detail when an image is fitted inside its physical box.
double effectiveImageDpi(
  int imageWidth,
  int imageHeight,
  double boxWidthMm,
  double boxHeightMm,
) {
  if (imageWidth <= 0 ||
      imageHeight <= 0 ||
      boxWidthMm <= 0 ||
      boxHeightMm <= 0) {
    throw const FormatException('Invalid image or placement dimensions.');
  }
  final fittedWidthMm = math.min(
    boxWidthMm,
    boxHeightMm * imageWidth / imageHeight,
  );
  return imageWidth * millimetresPerInch / fittedWidthMm;
}

double? lowestPlacedImageDpi(DesignDocument doc, Map<String, ui.Image> images) {
  double? lowest;
  for (final element in doc.elements) {
    final image = images[element.id];
    if (element.kind != ElementKind.image || image == null) continue;
    final dpi = effectiveImageDpi(
      image.width,
      image.height,
      element.width,
      element.height,
    );
    lowest = lowest == null ? dpi : math.min(lowest, dpi);
  }
  return lowest;
}

Future<Uint8List> renderPng(
  DesignDocument document,
  Map<String, ui.Image> images, {
  required int dpi,
}) async {
  final dimensions = exportDimensions(document, dpi);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  DesignPainter(document, images).paint(
    canvas,
    ui.Size(dimensions.width.toDouble(), dimensions.height.toDouble()),
  );
  final picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(dimensions.width, dimensions.height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not encode the image.');
    return bytes.buffer.asUint8List();
  } finally {
    image?.dispose();
    picture.dispose();
  }
}

class _PdfRequest {
  const _PdfRequest(this.png, this.widthMm, this.heightMm);
  final Uint8List png;
  final double widthMm;
  final double heightMm;
}

Future<Uint8List> _writePdf(_PdfRequest input) async {
  final pdf = pw.Document(compress: true);
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        mmToPoints(input.widthMm),
        mmToPoints(input.heightMm),
        marginAll: 0,
      ),
      build: (_) => pw.Image(pw.MemoryImage(input.png), fit: pw.BoxFit.fill),
    ),
  );
  return pdf.save();
}

Future<Uint8List> renderPdf(
  DesignDocument document,
  Map<String, ui.Image> images, {
  required int dpi,
}) async {
  final png = await renderPng(document, images, dpi: dpi);
  return compute(
    _writePdf,
    _PdfRequest(png, document.widthMm, document.heightMm),
  );
}
