import 'dart:convert';
import 'dart:typed_data';

import 'package:desksuite/document_scan/scan_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List page(int width, int height, int red) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(red, 100, 100));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('creates a real ordered, multi-page PDF with A4 physical dimensions', () async {
    final first = page(30, 50, 180), second = page(50, 30, 20);
    final firstCopy = Uint8List.fromList(first);
    final pdf = await createScanPdf(ScanPdfRequest([first, second]));
    final contents = latin1.decode(pdf);
    expect(contents.startsWith('%PDF-'), isTrue);
    expect(contents.contains('%%EOF'), isTrue);
    final boxes = RegExp(
      r'/MediaBox\s*\[\s*0(?:\.0+)?\s+0(?:\.0+)?\s+([0-9.]+)\s+([0-9.]+)\s*\]',
    ).allMatches(contents).toList();
    expect(boxes.length, 2);
    expect(double.parse(boxes[0].group(1)!), closeTo(210 * 72 / 25.4, .02));
    expect(double.parse(boxes[0].group(2)!), closeTo(297 * 72 / 25.4, .02));
    expect(double.parse(boxes[1].group(1)!), closeTo(297 * 72 / 25.4, .02));
    expect(double.parse(boxes[1].group(2)!), closeTo(210 * 72 / 25.4, .02));
    expect(first, orderedEquals(firstCopy));
  });

  test(
    'rejects missing, excessive, malformed and non-PNG document pages',
    () async {
      final good = page(2, 2, 10);
      await expectLater(
        createScanPdf(const ScanPdfRequest([])),
        throwsFormatException,
      );
      await expectLater(
        createScanPdf(ScanPdfRequest(List.filled(maxScanPages + 1, good))),
        throwsFormatException,
      );
      await expectLater(
        createScanPdf(
          ScanPdfRequest([
            Uint8List.fromList([1, 2]),
          ]),
        ),
        throwsFormatException,
      );
      final jpeg = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 2, height: 2)),
      );
      await expectLater(
        createScanPdf(ScanPdfRequest([jpeg])),
        throwsFormatException,
      );
    },
  );
}
