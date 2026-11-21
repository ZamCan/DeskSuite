import 'dart:typed_data';

import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('noise reduction saves filtered pixels and preserves source', () {
    final source = img.Image(width: 5, height: 5, numChannels: 4);
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        source.setPixelRgba(x, y, 230, 230, 230, 255);
      }
    }
    source.setPixelRgba(2, 2, 0, 0, 0, 255);
    final originalBytes = Uint8List.fromList(img.encodePng(source));
    final output = processPhoto(
      PhotoRequest(originalBytes, PhotoAction.reduceImpulseNoise),
    );
    final cleaned = img.decodePng(output.bytes)!;
    expect(cleaned.getPixel(2, 2).r.toInt(), 230);
    expect(img.decodePng(originalBytes)!.getPixel(2, 2).r.toInt(), 0);
    expect(output.width, 5);
    expect(output.height, 5);
  });
}
