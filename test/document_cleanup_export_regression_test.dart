import 'dart:typed_data';

import 'package:desksuite/document_scan/document_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('document cleanup encodes modified pixels rather than source', () {
    final source = img.Image(width: 2, height: 1, numChannels: 4);
    source.setPixelRgba(0, 0, 80, 120, 160, 255);
    source.setPixelRgba(1, 0, 40, 60, 80, 255);
    final bytes = Uint8List.fromList(img.encodePng(source));

    final original = processDocumentCleanup(
      DocumentCleanupRequest(bytes, mode: DocumentCleanupMode.original),
    );
    final grayscale = processDocumentCleanup(
      DocumentCleanupRequest(bytes, mode: DocumentCleanupMode.grayscale),
    );
    expect(original.bytes, orderedEquals(bytes));
    expect(grayscale.width, 2);
    expect(grayscale.height, 1);

    final decoded = img.decodePng(grayscale.bytes)!;
    final pixel = decoded.getPixel(0, 0);
    expect(pixel.r.toInt(), pixel.g.toInt());
    expect(pixel.g.toInt(), pixel.b.toInt());
    expect(pixel.r.toInt(), isNot(80));
  });
}
