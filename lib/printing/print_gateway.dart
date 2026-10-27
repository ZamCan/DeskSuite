import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../design/geometry.dart';

/// Platform boundary for the operating-system print dialog.
abstract class PrintGateway {
  Future<bool> printPdf({
    required Uint8List bytes,
    required String name,
    required double widthMm,
    required double heightMm,
  });
}

class SystemPrintGateway implements PrintGateway {
  const SystemPrintGateway();
  @override
  Future<bool> printPdf({
    required Uint8List bytes,
    required String name,
    required double widthMm,
    required double heightMm,
  }) {
    if (bytes.isEmpty ||
        !widthMm.isFinite ||
        !heightMm.isFinite ||
        widthMm <= 0 ||
        heightMm <= 0) {
      throw const FormatException('Invalid PDF or page dimensions.');
    }
    return Printing.layoutPdf(
      name: name,
      format: PdfPageFormat(
        mmToPoints(widthMm),
        mmToPoints(heightMm),
        marginAll: 0,
      ),
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }
}
