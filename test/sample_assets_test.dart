import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/document_scan/document_cleanup.dart';
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
        'shadowed-field-notes.png',
        'clean-practice-page.png',
        'shadowed-practice-page.png',
        'angled-practice-page.jpg',
        'practice-photo.jpg',
        'garden-clean-photo.jpg',
        'noisy-garden.png',
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
    'shadowed field notes exercise real color and adaptive B&W cleanup',
    () async {
      final bytes = await asset('shadowed-field-notes.png');
      final untouched = Uint8List.fromList(bytes);
      final before = img.decodePng(bytes)!;
      final color = img.decodePng(
        processDocumentCleanup(
          DocumentCleanupRequest(bytes, mode: DocumentCleanupMode.evenLighting),
        ).bytes,
      )!;
      final bw = img.decodePng(
        processDocumentCleanup(
          DocumentCleanupRequest(
            bytes,
            mode: DocumentCleanupMode.adaptiveBlackAndWhite,
          ),
        ).bytes,
      )!;
      expect(
        color.getPixel(30, 400).r,
        greaterThan(before.getPixel(30, 400).r + 40),
      );
      final chart = color.getPixel(200, 990);
      expect(chart.g, greaterThan(chart.r));
      expect(bw.getPixel(30, 400).r, 255);
      expect(bw.getPixel(200, 990).r, 0);
      expect(bytes, orderedEquals(untouched));
    },
  );

  test('practice report produces distinct real enhancement outputs', () async {
    final bytes = await asset('shadowed-practice-page.png');
    final original = Uint8List.fromList(bytes);
    final before = img.decodePng(bytes)!;
    img.Image result(DocumentCleanupMode mode, double amount) => img.decodePng(
      processDocumentCleanup(
        DocumentCleanupRequest(bytes, mode: mode, amount: amount),
      ).bytes,
    )!;
    final light = result(DocumentCleanupMode.lighten, .7);
    final shadow = result(DocumentCleanupMode.evenLighting, .7);
    final magic = result(DocumentCleanupMode.magicPro, .9);
    final bw = result(DocumentCleanupMode.adaptiveBlackAndWhite, .7);
    expect(
      light.getPixel(30, 500).r,
      greaterThan(before.getPixel(30, 500).r + 25),
    );
    expect(shadow.getPixel(30, 500).r, greaterThan(light.getPixel(30, 500).r));
    expect(magic.getPixel(30, 500).r, greaterThan(shadow.getPixel(30, 500).r));
    final green = magic.getPixel(300, 1215);
    expect(green.g, greaterThan(green.r));
    expect(bw.getPixel(30, 500).r, 255);
    expect(bw.getPixel(300, 1215).r, 0);
    expect(bytes, orderedEquals(original));
  });

  test('noisy garden sample really reduces an isolated speck', () async {
    final bytes = await asset('noisy-garden.png');
    final untouched = Uint8List.fromList(bytes);
    final before = img.decodePng(bytes)!;
    final after = img.decodePng(
      processPhoto(PhotoRequest(bytes, PhotoAction.reduceImpulseNoise)).bytes,
    )!;
    expect(before.getPixel(30, 354).r, 255);
    expect(after.getPixel(30, 354).r, lessThan(200));
    expect([after.width, after.height], [1376, 768]);
    expect(bytes, orderedEquals(untouched));
  });

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
