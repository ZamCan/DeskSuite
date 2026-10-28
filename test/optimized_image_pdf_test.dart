import 'dart:convert';
import 'dart:typed_data';

import 'package:desksuite/images/photo_processor.dart';
import 'package:desksuite/printing/optimized_image_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('optimized JPEG gets a contained A4 image-only page', () async {
    for (final size in [(30, 50), (50, 30)]) {
      final image = img.Image(width: size.$1, height: size.$2);
      final source = Uint8List.fromList(img.encodeJpg(image));
      final saved = Uint8List.fromList(source);
      final output = await optimizedImagePdf(
        PhotoResult(source, size.$1, size.$2),
      );
      final text = latin1.decode(output, allowInvalid: true);
      expect(text.startsWith('%PDF-'), isTrue);
      expect(text.contains('%%EOF'), isTrue);
      final box = RegExp(
        r'/MediaBox\s*\[\s*0(?:\.0+)?\s+0(?:\.0+)?\s+([0-9.]+)\s+([0-9.]+)\s*\]',
      ).firstMatch(text)!;
      final landscape = size.$1 > size.$2;
      expect(
        double.parse(box.group(1)!),
        closeTo((landscape ? 297 : 210) * 72 / 25.4, .02),
      );
      expect(
        double.parse(box.group(2)!),
        closeTo((landscape ? 210 : 297) * 72 / 25.4, .02),
      );
      expect(source, orderedEquals(saved));
    }
  });

  test('malformed or inconsistent JPEG is rejected', () async {
    await expectLater(
      optimizedImagePdf(PhotoResult(Uint8List.fromList([1, 2]), 10, 10)),
      throwsFormatException,
    );
    final bytes = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 10, height: 10)),
    );
    await expectLater(
      optimizedImagePdf(PhotoResult(bytes, 11, 10)),
      throwsFormatException,
    );
  });
}
