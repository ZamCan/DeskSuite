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

  test('canonical DeskSuite brand SVGs use the reference palette', () async {
    final mark = await rootBundle.loadString('assets/brand/desksuite-mark.svg');
    expect(mark, contains('aria-label="DeskSuite dimensional D and S mark"'));
    expect(mark, contains('fill="#f8fbff"'));
    expect(mark, contains('fill="#26c6da"'));
    expect(mark, contains('fill="#f3bd50"'));
    expect(mark, contains('viewBox="0 0 512 512"'));
    final appIcon = await rootBundle.loadString('assets/brand/desksuite-app-icon.svg');
    expect(appIcon, contains('aria-label="DeskSuite app icon"'));
    expect(appIcon, contains('fill="#153b66"'));
    expect(appIcon, contains('fill="#f8fbff"'));
    expect(appIcon, contains('fill="#26c6da"'));
    expect(appIcon, contains('fill="#f3bd50"'));
  });

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
