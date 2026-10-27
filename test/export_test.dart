import 'dart:convert';
import 'dart:ui' as ui;

import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/printing/design_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a real PNG and a correctly-sized single-page PDF', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final doc =
          DesignDocument.blank(
            name: 'Small print',
            widthMm: 50.8,
            heightMm: 25.4,
          ).copyWith(
            elements: [
              DesignElement(
                id: 'box',
                kind: ElementKind.rectangle,
                x: 2,
                y: 2,
                width: 20,
                height: 10,
                color: 0xffbe6348,
              ),
              DesignElement(
                id: 'text',
                kind: ElementKind.text,
                x: 2,
                y: 13,
                width: 35,
                height: 10,
                text: 'DeskSuite',
                fontSizePt: 12,
              ),
            ],
          );
      final png = await renderPng(doc, const {}, dpi: 100);
      expect(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 200);
      expect(frame.image.height, 100);
      frame.image.dispose();
      codec.dispose();
      final pdf = await renderPdf(doc, const {}, dpi: 100);
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
      final pdfText = latin1.decode(pdf, allowInvalid: true);
      final box = RegExp(
        r'/MediaBox\s*\[\s*0(?:\.0+)?\s+0(?:\.0+)?\s+([0-9.]+)\s+([0-9.]+)\s*\]',
      ).firstMatch(pdfText);
      expect(box, isNotNull, reason: 'PDF must contain a readable page box');
      expect(double.parse(box!.group(1)!), closeTo(144, 0.01));
      expect(double.parse(box.group(2)!), closeTo(72, 0.01));
    });
  });
  testWidgets('text alignment changes actual rendered position', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final base = DesignDocument.blank(
        name: 'Alignment',
        widthMm: 50.8,
        heightMm: 25.4,
      );
      final item = DesignElement(
        id: 'text',
        kind: ElementKind.text,
        x: 5,
        y: 5,
        width: 40,
        height: 15,
        text: 'Hi',
        fontSizePt: 12,
      );
      Future<List<int>> halves(TextAlignment alignment) async {
        final bytes = await renderPng(
          base.copyWith(elements: [item.copyWith(textAlignment: alignment)]),
          const {},
          dpi: 100,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final data = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var left = 0, right = 0;
        for (var y = 0; y < frame.image.height; y++) {
          for (var x = 0; x < frame.image.width; x++) {
            final offset = (y * frame.image.width + x) * 4;
            if (data.getUint8(offset) < 80 && data.getUint8(offset + 1) < 80) {
              if (x < frame.image.width / 2) {
                left++;
              } else {
                right++;
              }
            }
          }
        }
        frame.image.dispose();
        codec.dispose();
        return [left, right];
      }

      final left = await halves(TextAlignment.left);
      final right = await halves(TextAlignment.right);
      expect(left[0], greaterThan(left[1]));
      expect(right[1], greaterThan(right[0]));
    });
  });
}
