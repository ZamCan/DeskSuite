import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/document_scan/scan_pdf.dart';
import 'package:desksuite/document_scan/scan_processor.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> asset(String name) async {
    final data = await rootBundle.load('assets/samples/$name');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  test(
    'all bundled fictional samples decode and editable example imports',
    () async {
      for (final name in [
        'letter.png',
        'invoice.png',
        'application-form.png',
        'report-1.png',
        'report-2.png',
        'perspective-letter.png',
        'practice-photo.jpg',
      ]) {
        final bytes = await asset(name);
        final photo = processPhoto(PhotoRequest(bytes, PhotoAction.inspect));
        expect(photo.width, greaterThan(100), reason: name);
        expect(photo.height, greaterThan(100), reason: name);
      }
      final document = DesignDocument.decode(
        await asset('editable-example.dsdesign'),
      );
      expect(document.widthMm, 210);
      expect(document.heightMm, 297);
      expect(
        document.elements.where((e) => e.kind == ElementKind.text),
        isNotEmpty,
      );
    },
  );

  test(
    'perspective tutorial sample really corrects to A4 and creates a PDF',
    () async {
      final bytes = await asset('perspective-letter.png');
      const corners = ScanCorners(
        ScanPoint(142 / 919, 140 / 1039),
        ScanPoint(760 / 919, 84 / 1039),
        ScanPoint(824 / 919, 949 / 1039),
        ScanPoint(95 / 919, 910 / 1039),
      );
      final corrected = processScan(
        ScanRequest(bytes, corners: corners, outputAspect: 210 / 297),
      );
      expect(corrected.width / corrected.height, closeTo(210 / 297, .01));
      final image = img.decodePng(corrected.bytes)!;
      // The crop's corner lands on the light paper rather than the beige table.
      expect(image.getPixel(0, 0).r, greaterThan(220));
      final pdf = await createScanPdf(ScanPdfRequest([corrected.bytes]));
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    },
  );
}
