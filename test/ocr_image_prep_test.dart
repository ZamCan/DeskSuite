import 'dart:typed_data';

import 'package:desksuite/images/photo_processor.dart';
import 'package:desksuite/ocr/ocr_image_prep.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('prepareImageForOcr', () {
    test('downsamples only when the long edge exceeds the budget', () {
      final big = Uint8List.fromList(
        img.encodePng(img.Image(width: 4000, height: 2000)),
      );
      final prepared = prepareImageForOcr(
        OcrImageRequest(big, maxDimension: 1000),
      );
      final decoded = img.decodePng(prepared)!;
      expect(decoded.width, 1000);
      expect(decoded.height, 500);
      // Output is always PNG so the native decoder sees one predictable format.
      expect(prepared.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });

    test('leaves an image inside the budget at its original size', () {
      final small = Uint8List.fromList(
        img.encodePng(img.Image(width: 300, height: 200)),
      );
      final decoded = img.decodePng(
        prepareImageForOcr(OcrImageRequest(small, maxDimension: 2600)),
      )!;
      expect(decoded.width, 300);
      expect(decoded.height, 200);
    });

    test(
      'applies EXIF orientation rather than recognizing a sideways page',
      () {
        final source = img.Image(width: 60, height: 30);
        img.fill(source, color: img.ColorRgb8(255, 255, 255));
        // Orientation 6 means "rotate 90° clockwise to display correctly".
        source.exif.imageIfd.orientation = 6;
        final bytes = Uint8List.fromList(img.encodeJpg(source));
        final decoded = img.decodePng(
          prepareImageForOcr(OcrImageRequest(bytes)),
        )!;
        expect(decoded.width, 30);
        expect(decoded.height, 60);
      },
    );

    test(
      'accepts a bounded working scan PNG above the external picker limit',
      () {
        // A lossless, uncompressed scan copy can exceed 8 MiB even when its
        // dimensions are modest. Native pickers still limit external imports.
        final page = img.Image(width: 1450, height: 1450, numChannels: 4);
        final bytes = Uint8List.fromList(img.encodePng(page, level: 0));
        expect(bytes.length, greaterThan(maxPhotoInputBytes));
        expect(bytes.length, lessThan(maxPhotoWorkingBytes));
        final prepared = prepareImageForOcr(OcrImageRequest(bytes));
        final decoded = img.decodePng(prepared)!;
        expect([decoded.width, decoded.height], [1450, 1450]);
      },
    );

    test('rejects unsupported, tiny and wrongly budgeted inputs', () {
      expect(
        () => prepareImageForOcr(
          OcrImageRequest(Uint8List.fromList([1, 2, 3, 4])),
        ),
        throwsFormatException,
      );
      final tiny = Uint8List.fromList(
        img.encodePng(img.Image(width: 8, height: 8)),
      );
      expect(
        () => prepareImageForOcr(OcrImageRequest(tiny)),
        throwsFormatException,
      );
      expect(
        () => prepareImageForOcr(
          OcrImageRequest(Uint8List(0), maxDimension: 100),
        ),
        throwsFormatException,
      );
    });
  });
}
