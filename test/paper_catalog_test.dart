import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/printing/paper_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared catalog covers small sheets, A/B/C series, US sizes and posters', () {
    expect(paperSheetPresets.length, greaterThanOrEqualTo(50));
    expect(paperSheetPresets.any((p) => p.label.startsWith('A10')), isTrue);
    expect(paperSheetPresets.any((p) => p.label.startsWith('A0 poster')), isTrue);
    expect(paperSheetPresets.any((p) => p.label.startsWith('B0 poster')), isTrue);
    expect(paperSheetPresets.any((p) => p.label.startsWith('C10 envelope')), isTrue);
    expect(paperSheetPresets.any((p) => p.label.startsWith('US Legal')), isTrue);
    expect(paperSheetPresets.any((p) => p.label.startsWith('Photo 3.5 × 5')), isTrue);
    expect(paperSheetPresets.any((p) => p.label.startsWith('Large format 48 × 72')), isTrue);
    expect(paperSheetPresets.every((p) => p.widthMm > 0 && p.heightMm > 0), isTrue);
  });

  test('large poster canvases are valid physical documents', () {
    final poster = DesignDocument.blank(
      name: 'Large format poster',
      widthMm: 1219.2,
      heightMm: 1828.8,
    );
    expect(poster.widthMm, 1219.2);
    expect(poster.heightMm, 1828.8);
    expect(
      () => DesignDocument.blank(name: 'Out of bounds', widthMm: 2501, heightMm: 500),
      throwsFormatException,
    );
  });
}
