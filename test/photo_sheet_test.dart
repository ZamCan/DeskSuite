import 'dart:convert';
import 'dart:typed_data';

import 'package:desksuite/printing/paper_catalog.dart';
import 'package:desksuite/printing/photo_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  PhotoSheetSpec spec({int copies = 8}) => PhotoSheetSpec(
    pageWidthMm: 210,
    pageHeightMm: 297,
    photoWidthMm: 35,
    photoHeightMm: 45,
    marginMm: 10,
    spacingMm: 3,
    copies: copies,
  );

  test('sheet geometry respects margins, spacing, dimensions and capacity', () {
    final sheet = spec();
    expect(sheet.columns, 5);
    expect(sheet.rows, 5);
    expect(sheet.capacity, 25);
    final positions = sheet.positions();
    expect(positions.length, 8);
    expect([positions.first.leftMm, positions.first.topMm], [10, 10]);
    expect([positions[1].leftMm, positions[1].topMm], [48, 10]);
    expect([positions[5].leftMm, positions[5].topMm], [10, 58]);
    for (final p in positions) {
      expect(
        p.leftMm + sheet.photoWidthMm,
        lessThanOrEqualTo(sheet.pageWidthMm - sheet.marginMm),
      );
      expect(
        p.topMm + sheet.photoHeightMm,
        lessThanOrEqualTo(sheet.pageHeightMm - sheet.marginMm),
      );
    }
    expect(() => spec(copies: 26).positions(), throwsFormatException);
    expect(
      () => PhotoSheetSpec(
        pageWidthMm: double.nan,
        pageHeightMm: 297,
        photoWidthMm: 35,
        photoHeightMm: 45,
        marginMm: 10,
        spacingMm: 3,
        copies: 1,
      ),
      throwsFormatException,
    );
  });

  test('every listed medium accepts a small fitting photo layout', () {
    for (final paper in paperSheetPresets) {
      final sheet = PhotoSheetSpec(
        pageWidthMm: paper.widthMm,
        pageHeightMm: paper.heightMm,
        photoWidthMm: 5,
        photoHeightMm: 5,
        marginMm: 0,
        spacingMm: 0,
        copies: 1,
      );
      expect(sheet.positions(), hasLength(1), reason: paper.label);
    }
  });

  test('small label and miniature media sizes remain valid', () {
    final miniature = PhotoSheetSpec(
      pageWidthMm: 26,
      pageHeightMm: 37,
      photoWidthMm: 5,
      photoHeightMm: 5,
      marginMm: 0,
      spacingMm: 0,
      copies: 1,
    );
    expect(miniature.capacity, greaterThan(0));
    expect(miniature.positions(), hasLength(1));
  });

  test('the default 4 × 6 media can fit the default four photos', () {
    final sheet = PhotoSheetSpec(
      pageWidthMm: 101.6,
      pageHeightMm: 152.4,
      photoWidthMm: 35,
      photoHeightMm: 45,
      marginMm: 10,
      spacingMm: 3,
      copies: 4,
    );
    expect(sheet.capacity, 4);
    expect(sheet.positions(), hasLength(4));
  });

  test(
    'poster-size custom media is supported within the production bounds',
    () {
      final poster = PhotoSheetSpec(
        pageWidthMm: 1219.2,
        pageHeightMm: 1828.8,
        photoWidthMm: 50,
        photoHeightMm: 50,
        marginMm: 20,
        spacingMm: 5,
        copies: 1,
      );
      expect(poster.capacity, greaterThan(0));
      expect(
        () => PhotoSheetSpec(
          pageWidthMm: 2501,
          pageHeightMm: 100,
          photoWidthMm: 50,
          photoHeightMm: 50,
          marginMm: 0,
          spacingMm: 0,
          copies: 1,
        ),
        throwsFormatException,
      );
    },
  );

  test('repeated photo sheet produces a real physically sized A4 PDF', () async {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 8, height: 10)),
    );
    final pdf = await generatePhotoSheet(PhotoSheetRequest(bytes, spec()));
    expect(latin1.decode(pdf.take(5).toList()), '%PDF-');
    final text = latin1.decode(pdf, allowInvalid: true);
    final box = RegExp(
      r'/MediaBox\s*\[\s*0(?:\.0+)?\s+0(?:\.0+)?\s+([0-9.]+)\s+([0-9.]+)\s*\]',
    ).firstMatch(text);
    expect(box, isNotNull);
    expect(double.parse(box!.group(1)!), closeTo(210 * 72 / 25.4, .02));
    expect(double.parse(box.group(2)!), closeTo(297 * 72 / 25.4, .02));
  });
}
