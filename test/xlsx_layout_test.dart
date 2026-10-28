import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/office/render/office_layout.dart';
import 'package:desksuite/office/render/xlsx_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixture is a real workbook written by openpyxl: bold white-on-ink
/// headers, a currency number format, a date, a merged banner and a set
/// column width. These are the values a spreadsheet application shows.
void main() {
  late OfficeWorkbook book;

  setUpAll(() {
    final bytes = File('test/fixtures/office/ledger.xlsx').readAsBytesSync();
    book = parseXlsx(Uint8List.fromList(bytes));
  });

  test('reads sheet names, cells and merged ranges', () {
    expect(book.sheets, hasLength(1));
    final sheet = book.sheets.single;
    expect(sheet.name, 'Sales');
    expect(sheet.rows.length, greaterThanOrEqualTo(7));
  });

  test('formats currency cells the way the format code says', () {
    final sheet = book.sheets.single;
    final price = sheet.rows[1][2]!;
    expect(price.display, '4,500.00 TZS');
    expect(price.number, 4500);
    // The file sets no alignment here, so the application's own rule applies:
    // numbers right-align, text left-aligns.
    expect(price.align, OfficeAlign.right);
  });

  test('applies bold and a solid fill from styles.xml', () {
    final header = book.sheets.single.rows[0][0]!;
    expect(header.display, 'Item');
    expect(header.bold, isTrue);
    expect(header.fill!.argb, 0xFF292824);
    expect(header.color!.argb, 0xFFF7F5F0);
  });

  test('renders a date serial as the date the file meant', () {
    final date = book.sheets.single.rows[4][1]!;
    expect(date.isDate, isTrue);
    expect(date.display, '2026-10-28');
    expect(date.kind, OfficeCellKind.date);
  });

  test('keeps the merged range: anchor spans, covered cells go blank', () {
    final sheet = book.sheets.single;
    final anchor = sheet.rows[6][0]!;
    expect(anchor.display, 'Merged banner row');
    expect(anchor.columnSpan, 4);
    expect(sheet.rows[6][1]!.mergedAway, isTrue);
    expect(sheet.rows[6][3]!.mergedAway, isTrue);
  });

  test('keeps the formula, and does not invent its result', () {
    final cell = book.sheets.single.rows[1][3]!;
    expect(cell.formula, 'B2*C2');
    // The file has no cached value for this formula, and DeskSuite does not
    // evaluate formulas: it shows the formula rather than a number it made up.
    expect(cell.kind, OfficeCellKind.formula);
    expect(cell.display, '=B2*C2');
  });

  test('column widths come from the file, not a default', () {
    final sheet = book.sheets.single;
    expect(sheet.columnWidthChars[0], closeTo(22, .5));
    expect(sheet.columnWidthChars[1], closeTo(10, .5));
  });

  test('a non-ZIP file is refused by name', () {
    expect(
      () => parseXlsx(Uint8List.fromList('hello'.codeUnits)),
      throwsA(
        isA<XlsxLayoutException>().having(
          (e) => e.message,
          'message',
          contains('not a valid ZIP'),
        ),
      ),
    );
  });

  test('a presentation is not silently read as a workbook', () {
    final bytes = File('test/fixtures/office/deck.pptx').readAsBytesSync();
    expect(
      () => parseXlsx(Uint8List.fromList(bytes)),
      throwsA(
        isA<XlsxLayoutException>().having(
          (e) => e.message,
          'message',
          contains('not an Excel workbook'),
        ),
      ),
    );
  });

  group('formatExcelNumber', () {
    String render(double value, String code) => formatExcelNumber(value, code);

    test('thousands separators and fixed decimals', () {
      expect(render(4500, '#,##0'), '4,500');
      expect(render(4500, '#,##0.00'), '4,500.00');
      expect(render(0.5, '0.00'), '0.50');
      expect(render(-1234.4, '#,##0.00'), '-1,234.40');
    });

    test('currency literals are emitted verbatim', () {
      expect(render(4500, '#,##0.00" TZS"'), '4,500.00 TZS');
      expect(render(999, r'"TSh "#,##0'), 'TSh 999');
    });

    test('percent multiplies by a hundred', () {
      expect(render(0.25, '0%'), '25%');
      expect(render(0.256, '0.0%'), '25.6%');
    });

    test('date formats read the serial the way Excel does', () {
      // 46323 is 2026-10-28 in the 1900 date system.
      expect(render(46323, 'yyyy-mm-dd'), '2026-10-28');
      expect(render(46323, 'd-mmm-yy'), '28-Oct-26');
      expect(render(46323, 'dddd'), 'Wednesday');
    });

    test('negative and zero sections are honoured', () {
      expect(render(-5, '#,##0;(#,##0)'), '(5)');
      // Three sections: positive, negative, zero. With two sections the
      // second is the negative one, which the previous case covers.
      expect(render(0, '#,##0;(#,##0);"zero"'), 'zero');
    });

    test('an unknown format falls back to the number, never the code', () {
      expect(render(12.5, 'General'), contains('12.5'));
      expect(render(12.5, ''), contains('12.5'));
    });

    test('scaling commas divide by a thousand', () {
      expect(render(1500000, '#,##0,,"M"'), '2M');
    });
  });
}
