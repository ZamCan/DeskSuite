import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/design_document.dart';
import '../design/design_renderer.dart';
import '../design/geometry.dart';
import 'image_detail.dart';
import 'raster_budget.dart';

export 'image_detail.dart' show ImagePlacementFit, effectiveImageDpi;
export 'raster_budget.dart'
    show ExportDimensions, fittingRasterDpi, maxExportPixels, maxExportSide;

ExportDimensions exportDimensions(DesignDocument doc, int dpi) =>
    boundedRasterDimensions(doc.widthMm, doc.heightMm, dpi);

/// The renderer fills each design image frame with BoxFit.cover, so estimate
/// the resolution after that crop rather than using a contain-fit estimate.
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
      fit: ImagePlacementFit.cover,
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
