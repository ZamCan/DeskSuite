import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/office/render/office_layout.dart';
import 'package:desksuite/office/render/pptx_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixture is a real deck written by python-pptx: a 10 x 7.5 inch slide,
/// a bold 36 pt title at a known offset, a terracotta rule, a PNG and a 2x3
/// table. Every expectation below is a value that writer put in the file.
void main() {
  late OfficeDeck deck;

  setUpAll(() {
    final bytes = File('test/fixtures/office/deck.pptx').readAsBytesSync();
    deck = parsePptx(Uint8List.fromList(bytes));
  });

  test('reads the declared slide size, not an assumed 4:3', () {
    expect(deck.slides, hasLength(2));
    expect(deck.slides.first.widthPt, closeTo(720, .5)); // 10 in
    expect(deck.slides.first.heightPt, closeTo(540, .5)); // 7.5 in
    expect(deck.slides.first.aspectRatio, closeTo(10 / 7.5, .01));
  });

  test('positions the title exactly where the file puts it', () {
    final title = deck.slides.first.shapes.firstWhere(
      (shape) => shape.text?.plainText == 'Quarterly review',
    );
    // 1 in from the left, 0.6 in from the top, 8 x 1 in.
    expect(title.boundsPt!.left, closeTo(72, .5));
    expect(title.boundsPt!.top, closeTo(43.2, .5));
    expect(title.boundsPt!.width, closeTo(576, .5));
    expect(title.boundsPt!.height, closeTo(72, .5));
  });

  test('keeps run formatting: size, weight and document colour', () {
    final title = deck.slides.first.shapes.firstWhere(
      (shape) => shape.text?.plainText == 'Quarterly review',
    );
    final run = title.text!.paragraphs.first.runs.first;
    expect(run.sizePt, 36);
    expect(run.bold, isTrue);
    expect(run.color!.argb, 0xFF292824);
  });

  test('reads solid fills and leaves unfilled shapes unfilled', () {
    final band = deck.slides.first.shapes.firstWhere(
      (shape) => shape.name.startsWith('Rectangle'),
    );
    expect(band.fill!.argb, 0xFFB96045);
    expect(band.boundsPt!.width, closeTo(576, .5));

    final title = deck.slides.first.shapes.firstWhere(
      (shape) => shape.text?.plainText == 'Quarterly review',
    );
    expect(title.fill, isNull, reason: 'a text box is not filled');
  });

  test('extracts the embedded picture with real image bytes', () {
    final picture = deck.slides.first.shapes.firstWhere(
      (shape) => shape.kind == OfficeShapeKind.picture,
    );
    expect(picture.picture, isNotNull);
    expect(picture.picture!.mimeType, 'image/png');
    // PNG signature: the bytes are the image, not a path or a placeholder.
    expect(picture.picture!.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(picture.boundsPt!.width, closeTo(288, .5)); // 4 in
    expect(picture.boundsPt!.height, closeTo(144, .5)); // 2 in
  });

  test('reads table geometry and cell text', () {
    final table = deck.slides.first.shapes.firstWhere(
      (shape) => shape.kind == OfficeShapeKind.table,
    );
    expect(table.table!.rows, hasLength(2));
    expect(table.table!.columnWidthsPt, hasLength(3));
    expect(table.table!.rows.first.cells.first.text.plainText, 'Item');
    expect(table.table!.rows.last.cells.last.text.plainText, '4,500');
    // Column widths come from the file and roughly sum to the frame width.
    final total = table.table!.columnWidthsPt.reduce((a, b) => a + b);
    expect(total, closeTo(3.5 * 72, 6));
  });

  test('slide order follows the presentation, not the file names', () {
    expect(
      deck.slides[1].shapes.map((s) => s.text?.plainText),
      contains('Second slide'),
    );
  });

  test('a damaged package is refused with a message, not a parser trace', () {
    expect(
      () => parsePptx(Uint8List.fromList('not a zip'.codeUnits)),
      throwsA(
        isA<PptxLayoutException>().having(
          (e) => e.message,
          'message',
          contains('damaged or not a valid ZIP'),
        ),
      ),
    );
  });

  test('a zip that is not a presentation is named as such', () {
    // A minimal ZIP with one entry: valid container, wrong contents.
    final bytes = File('test/fixtures/office/ledger.xlsx').readAsBytesSync();
    expect(
      () => parsePptx(Uint8List.fromList(bytes)),
      throwsA(
        isA<PptxLayoutException>().having(
          (e) => e.message,
          'message',
          contains('not a PowerPoint presentation'),
        ),
      ),
    );
  });
}
