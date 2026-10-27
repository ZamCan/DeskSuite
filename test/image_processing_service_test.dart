import 'dart:convert';
import 'dart:typed_data';

import 'package:desksuite/images/image_processing_service.dart';
import 'package:flutter_test/flutter_test.dart';

const samplePng = 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAMCAIAAADkharWAAAAF0lEQVR4nGPs2VLBQApgIkn1qIYRpAEADVwB0JlVGsIAAAAASUVORK5CYII=';

void main() {
  group('ImageProcessingService', () {
    final service = ImageProcessingService();
    final source = Uint8List.fromList(base64Decode(samplePng));

    test('inspects source dimensions', () {
      final dimensions = service.inspect(source);
      expect(dimensions.width, 16);
      expect(dimensions.height, 12);
    });

    test('resizes with preserved aspect ratio and valid PNG output', () {
      final result = service.resizeAndEncode(
        sourceBytes: source,
        targetWidth: 32,
        targetHeight: 32,
        preserveAspectRatio: true,
        format: ImageOutputFormat.png,
      );
      expect(result.width, 32);
      expect(result.height, 24);
      expect(result.bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(service.inspect(result.bytes).width, 32);
    });

    test('can resize to exact dimensions and encode JPEG', () {
      final result = service.resizeAndEncode(
        sourceBytes: source,
        targetWidth: 40,
        targetHeight: 20,
        preserveAspectRatio: false,
        format: ImageOutputFormat.jpeg,
        jpegQuality: 80,
      );
      expect(result.width, 40);
      expect(result.height, 20);
      expect(result.bytes[0], 0xff);
      expect(result.bytes[1], 0xd8);
    });

    test('rejects excessive output dimensions', () {
      expect(
        () => service.resizeAndEncode(
          sourceBytes: source,
          targetWidth: 8192,
          targetHeight: 8192,
          preserveAspectRatio: false,
          format: ImageOutputFormat.png,
        ),
        throwsFormatException,
      );
    });
  });
}
