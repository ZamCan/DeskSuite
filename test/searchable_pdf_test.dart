import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:desksuite/ocr/ocr_engine.dart';
import 'package:desksuite/ocr/searchable_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';

Uint8List samplePng({int width = 600, int height = 800}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

const words = <OcrWord>[
  OcrWord(
    text: 'INVOICE',
    left: 40,
    top: 60,
    right: 200,
    bottom: 100,
    confidence: 93,
  ),
  OcrWord(
    text: 'Total',
    left: 40,
    top: 140,
    right: 120,
    bottom: 172,
    confidence: 88,
  ),
  OcrWord(
    text: '5000',
    left: 400,
    top: 140,
    right: 520,
    bottom: 172,
    confidence: 51,
  ),
];

OcrResult resultFor(int width, int height) => OcrResult(
  text: 'INVOICE\nTotal 5000',
  words: words,
  imageWidth: width,
  imageHeight: height,
  language: 'eng',
  meanConfidence: 77.3,
);

/// Collects every readable content stream so a test can prove the recognized
/// words really are inside the PDF, not only that a file was produced.
String inflatedStreams(Uint8List pdf) {
  final text = latin1.decode(pdf, allowInvalid: true);
  final buffer = StringBuffer();
  var index = 0;
  while (true) {
    final start = text.indexOf('stream', index);
    if (start < 0) break;
    var dataStart = start + 'stream'.length;
    if (dataStart < text.length && text[dataStart] == '\r') dataStart++;
    if (dataStart < text.length && text[dataStart] == '\n') dataStart++;
    final end = text.indexOf('endstream', dataStart);
    if (end < 0) break;
    final data = pdf.sublist(dataStart, end);
    try {
      buffer.write(latin1.decode(ZLibDecoder().decodeBytes(data)));
    } catch (_) {
      // Not a Flate stream (fonts, images with other filters); ignore.
    }
    index = end + 'endstream'.length;
  }
  return buffer.toString();
}

void main() {
  group('PageFit', () {
    test('contains a portrait image without distortion', () {
      final fit = PageFit.contain(
        imageWidth: 600,
        imageHeight: 800,
        format: const PdfPageFormat(300, 300),
      );
      expect(fit.width / fit.height, closeTo(600 / 800, .0001));
      expect(fit.width, lessThanOrEqualTo(300.0001));
      expect(fit.height, lessThanOrEqualTo(300.0001));
      expect(fit.offsetX, greaterThanOrEqualTo(0));
      expect(fit.offsetY, greaterThanOrEqualTo(0));
    });

    test('maps a word box from pixels into page points', () {
      final fit = PageFit.contain(
        imageWidth: 600,
        imageHeight: 800,
        format: const PdfPageFormat(600, 800),
      );
      final rect = fit.wordRect(words.first);
      expect(rect.left, closeTo(40, .001));
      expect(rect.top, closeTo(60, .001));
      expect(rect.width, closeTo(160, .001));
      expect(rect.height, closeTo(40, .001));
    });

    test('rejects a page with no usable image size', () {
      expect(
        () => PageFit.contain(
          imageWidth: 0,
          imageHeight: 10,
          format: PdfPageFormat.a4,
        ),
        throwsFormatException,
      );
    });
  });

  group('buildSearchablePdf', () {
    test('embeds the page image and a real text layer', () async {
      final bytes = await buildSearchablePdf([
        SearchablePage(imageBytes: samplePng(), result: resultFor(600, 800)),
      ]);
      expect(bytes.length, greaterThan(1000));
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');

      final pdfText = latin1.decode(bytes, allowInvalid: true);
      // One page object, one embedded image.
      expect(RegExp(r'/Type\s*/Page[^s]').allMatches(pdfText).length, 1);
      // The page image must be an embedded XObject, not a path redraw.
      expect(RegExp(r'/Subtype\s*/Image').hasMatch(pdfText), isTrue);

      final content = inflatedStreams(bytes);
      for (final word in words) {
        expect(
          content,
          contains(word.text),
          reason: '${word.text} must be in the page text layer',
        );
      }
    });

    test('keeps pages in the order supplied', () async {
      final bytes = await buildSearchablePdf([
        SearchablePage(imageBytes: samplePng(), result: resultFor(600, 800)),
        SearchablePage(
          imageBytes: samplePng(width: 800, height: 600),
          result: resultFor(800, 600),
        ),
      ]);
      final pdfText = latin1.decode(bytes, allowInvalid: true);
      expect(RegExp(r'/Type\s*/Page[^s]').allMatches(pdfText).length, 2);
      // Both pages carry the recognized text.
      final content = inflatedStreams(bytes);
      expect('INVOICE'.allMatches(content).length, greaterThanOrEqualTo(2));
    });

    test('refuses to build a PDF with nothing to search', () async {
      await expectLater(
        buildSearchablePdf([
          SearchablePage(
            imageBytes: samplePng(),
            result: const OcrResult(
              text: '',
              words: <OcrWord>[],
              imageWidth: 600,
              imageHeight: 800,
              language: 'eng',
            ),
          ),
        ]),
        throwsFormatException,
      );
    });

    test('refuses an empty page list and an empty image', () async {
      await expectLater(buildSearchablePdf([]), throwsFormatException);
      await expectLater(
        buildSearchablePdf([
          SearchablePage(imageBytes: Uint8List(0), result: resultFor(600, 800)),
        ]),
        throwsFormatException,
      );
    });
  });
}
