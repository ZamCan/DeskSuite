import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../design/geometry.dart';
import 'print_job.dart';

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


/// Routes an already-rendered print job through the existing OS print boundary.
/// The PDF bytes must already use the requested media geometry; this method
/// validates the job and keeps the physical output dimensions authoritative.
extension PreparedPrintJobGateway on PrintGateway {
  Future<bool> printPreparedJob({
    required Uint8List bytes,
    required String name,
    required PrintJob job,
  }) {
    if (!job.isValid) {
      throw const FormatException('Invalid print job cannot be dispatched.');
    }
    return printPdf(
      bytes: bytes,
      name: name,
      widthMm: job.media.widthMm,
      heightMm: job.media.heightMm,
    );
  }
}
