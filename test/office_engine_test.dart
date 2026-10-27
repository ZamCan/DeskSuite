import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:desksuite/office/office_engine.dart';
import 'package:desksuite/office/office_format.dart';
import 'package:desksuite/office/office_package.dart';
import 'package:desksuite/office/office_reader.dart';
import 'package:desksuite/office/office_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/office_fixtures.dart';

String packageText(Uint8List zip, String part) {
  final archive = ZipDecoder().decodeBytes(zip);
  final file = archive.files.firstWhere((f) => f.name == part);
  final content = file.readBytes()!;
  return utf8.decode(content, allowMalformed: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('format detection', () {
    test('identifies real containers regardless of the file name', () {
      expect(detectOfficeFile(docxFixture()).format, OfficeFormat.docx);
      expect(detectOfficeFile(xlsxFixture()).format, OfficeFormat.xlsx);
      expect(detectOfficeFile(pptxFixture()).format, OfficeFormat.pptx);
      expect(detectOfficeFile(odtFixture()).format, OfficeFormat.odt);
      expect(detectOfficeFile(odsFixture()).format, OfficeFormat.ods);
      expect(detectOfficeFile(rtfFixture()).format, OfficeFormat.rtf);
      expect(detectOfficeFile(htmlFixture()).format, OfficeFormat.html);
      expect(
        detectOfficeFile(Uint8List.fromList(utf8.encode('plain words'))).format,
        OfficeFormat.txt,
      );
    });

    test('never trusts a misleading extension', () {
      // An ODT named .docx is still an ODT.
      final detected = detectOfficeFile(odtFixture(), fileName: 'letter.docx');
      expect(detected.format, OfficeFormat.odt);
    });

    test('recognises legacy binary and explains the limit', () {
      final detected = detectOfficeFile(
        legacyOleFixture(),
        fileName: 'old.xls',
      );
      expect(detected.format, OfficeFormat.xls);
      expect(detected.detail, contains('cannot be read'));
    });

    test('writable flags match real built-in output formats', () {
      expect(OfficeFormat.docx.isWritable, isFalse);
      expect(OfficeFormat.xlsx.isWritable, isFalse);
      expect(OfficeFormat.pptx.isWritable, isFalse);
      expect(OfficeFormat.odt.isWritable, isTrue);
      expect(OfficeFormat.ods.isWritable, isTrue);
      expect(OfficeFormat.pdf.isWritable, isTrue);
      expect(OfficeFormat.txt.isWritable, isTrue);
    });

    test('rejects empty, random and unsupported packages', () {
      expect(() => detectOfficeFile(Uint8List(0)), throwsFormatException);
      expect(
        () => detectOfficeFile(Uint8List.fromList([0x01, 0x02, 0x03, 0x04])),
        throwsFormatException,
      );
      expect(
        () => detectOfficeFile(odfNotAnOfficeDoc()),
        throwsFormatException,
      );
    });
  });

  group('DOCX', () {
    test('reads headings, emphasis, tables and page breaks', () {
      final document = readOfficeDocument(docxFixture());
      expect(document.format, OfficeFormat.docx);
      expect(document.title, 'Sample invoice');

      final headings = document.blocks.where((b) => b.headingLevel == 1);
      expect(headings.single.text, 'INVOICE DS-2026-014');

      final bold = document.blocks.firstWhere(
        (b) => b.kind == OfficeBlockKind.paragraph && b.bold,
      );
      expect(bold.text, contains('Total:'));
      expect(bold.text, contains('5,000 TZS'));

      final rows = document.blocks.where((b) => b.kind == OfficeBlockKind.row);
      expect(rows, hasLength(2));
      expect(rows.first.cells, ['Item', 'Qty']);
      expect(rows.last.cells, ['A4 paper', '2']);

      expect(
        document.blocks.any((b) => b.kind == OfficeBlockKind.pageBreak),
        isTrue,
      );
      expect(document.plainText, contains('Appendix page'));
      expect(document.notes, isNotEmpty);
    });

    test('rejects a package without a main document part', () {
      final broken = OfficeFixture()..add('word/styles.xml', '<x/>');
      expect(() => readOfficeDocument(broken.build()), throwsFormatException);
    });

    test('rejects malformed XML with a readable message', () {
      final broken = OfficeFixture()
        ..add('word/document.xml', '<w:document <<< not xml');
      expect(
        () => readOfficeDocument(broken.build(), fileName: 'x.docx'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('not valid XML'),
          ),
        ),
      );
    });
  });

  group('XLSX', () {
    test('reads shared strings, numbers, formulas and booleans per sheet', () {
      final document = readOfficeDocument(xlsxFixture());
      expect(document.sheetNames, ['Stock', 'Sales']);
      final rows = document.blocks
          .where((b) => b.kind == OfficeBlockKind.row)
          .toList();
      expect(rows.first.cells, ['Notebook', 'Price, TZS']);
      expect(rows[1].cells, ['Notebook', '3500']);
      // A formula cell shows its calculated value.
      expect(rows[2].cells.first, '3500');
      expect(rows[2].cells.last, 'TRUE');
      expect(rows.last.cells, ['Counter sales']);
    });

    test('rejects a workbook with no readable sheets', () {
      final broken = OfficeFixture()
        ..add(
          'xl/workbook.xml',
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
              '2006/main"><sheets/></workbook>',
        );
      expect(() => readOfficeDocument(broken.build()), throwsFormatException);
    });
  });

  group('PPTX and ODF', () {
    test('reads slide text in slide order', () {
      final document = readOfficeDocument(pptxFixture());
      expect(document.slideCount, 2);
      final paragraphs = document.blocks
          .where((b) => b.kind == OfficeBlockKind.paragraph)
          .map((b) => b.text)
          .toList();
      expect(
        paragraphs.indexOf('Welcome to DeskSuite'),
        lessThan(paragraphs.indexOf('Stationery catalogue')),
      );
    });

    test('reads ODT headings and text', () {
      final document = readOfficeDocument(odtFixture());
      expect(document.blocks.first.headingLevel, 1);
      expect(document.blocks.first.text, 'Barua rasmi');
      expect(document.plainText, contains('karibu DeskSuite'));
    });

    test('reads ODS tables', () {
      final document = readOfficeDocument(odsFixture());
      expect(document.sheetNames, ['Daftari']);
      expect(document.tableText, contains('Kalamu\t500'));
    });
  });

  group('RTF and HTML', () {
    test('reads RTF paragraphs and unescapes braces', () {
      final document = readOfficeDocument(rtfFixture());
      expect(document.plainText, contains('Kumbuka'));
      expect(document.plainText, contains('Mstari wa pili.'));
      expect(document.plainText, isNot(contains('fonttbl')));
    });

    test('converts HTML to readable text without scripts', () {
      final text = htmlToText(
        Uint8List.fromList(
          utf8.encode(
            '<html><head><style>p{color:red}</style><script>alert(1)</script>'
            '</head><body><h1>Risiti</h1><p>A &amp; B</p>'
            '<ul><li>Kwanza</li></ul></body></html>',
          ),
        ),
      );
      expect(text, contains('Risiti'));
      expect(text, contains('A & B'));
      expect(text, contains('• Kwanza'));
      expect(text, isNot(contains('alert')));
      expect(text, isNot(contains('color:red')));
    });
  });

  group('safety bounds', () {
    test('rejects an archive with too many parts', () {
      expect(
        () => readOfficeDocument(odfZipBombFixture()),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('too many parts'),
          ),
        ),
      );
    });

    test('rejects an oversized archive before unpacking', () {
      expect(
        () => readOfficeDocument(
          Uint8List(OfficePackageLimits.maxArchiveBytes + 1),
        ),
        throwsFormatException,
      );
    });
  });

  group('conversion registry', () {
    test('offers only routes that can really run', () async {
      final engine = OfficeEngine();
      final docxRoutes = await engine.routesFor(OfficeFormat.docx);
      expect(
        docxRoutes.map((r) => r.id),
        containsAll(['DOCX→PDF', 'DOCX→TXT', 'DOCX→ODT']),
      );
      expect(docxRoutes.any((r) => r.id == 'DOCX→XLSX'), isFalse);

      final xlsxRoutes = await engine.routesFor(OfficeFormat.xlsx);
      expect(
        xlsxRoutes.map((r) => r.id),
        containsAll(['XLSX→PDF', 'XLSX→TXT', 'XLSX→ODS']),
      );

      final legacy = await engine.routesFor(OfficeFormat.xls);
      expect(legacy, isEmpty, reason: 'no engine can read legacy binary files');
    });

    test('states the fidelity of every route', () async {
      for (final route in OfficeEngine.builtInRoutes) {
        expect(route.detail, isNotEmpty);
        expect(route.engine, isNotEmpty);
      }
    });

    test('adds rendered routes only when an external engine exists', () async {
      final without = OfficeEngine();
      expect((await without.routesFor(OfficeFormat.doc)).isEmpty, isTrue);

      final withLibre = OfficeEngine(external: _FakeLibreOffice());
      final routes = await withLibre.routesFor(OfficeFormat.doc);
      expect(routes.single.requiresExternalEngine, isTrue);
      expect(routes.single.fidelity, Fidelity.rendered);
    });
  });

  group('conversions', () {
    test('DOCX → PDF produces a valid, reopened PDF with the text', () async {
      final engine = OfficeEngine();
      final routes = await engine.routesFor(OfficeFormat.docx);
      final route = routes.firstWhere((r) => r.id == 'DOCX→PDF');
      final conversion = await engine.convert(
        bytes: docxFixture(),
        route: route,
        sourceName: 'invoice.docx',
      );

      expect(conversion.fileName, 'invoice.pdf');
      expect(latin1.decode(conversion.bytes.sublist(0, 5)), '%PDF-');
      expect(conversion.bytes.length, greaterThan(1000));
      // Content survives; the note about images is carried through.
      final raw = latin1.decode(conversion.bytes, allowInvalid: true);
      expect(RegExp(r'/Type\s*/Page').hasMatch(raw), isTrue);
      expect(conversion.notes, isNotEmpty);
    });

    test('XLSX → CSV keeps rows and quotes commas', () async {
      final engine = OfficeEngine();
      final routes = await engine.routesFor(OfficeFormat.xlsx);
      final route = routes.firstWhere((r) => r.to == OfficeFormat.txt);
      final conversion = await engine.convert(
        bytes: xlsxFixture(),
        route: route,
        sourceName: 'stock.xlsx',
      );
      expect(conversion.fileName, 'stock.csv');
      final csv = utf8.decode(conversion.bytes);
      expect(csv, contains('Notebook'));
      expect(csv, contains('"Price, TZS"'));
      expect(csv, contains('# Sheet: Sales'));
    });

    test('DOCX → ODT writes a real OpenDocument package', () async {
      final engine = OfficeEngine();
      final routes = await engine.routesFor(OfficeFormat.docx);
      final route = routes.firstWhere((r) => r.to == OfficeFormat.odt);
      final conversion = await engine.convert(
        bytes: docxFixture(),
        route: route,
        sourceName: 'barua.docx',
      );
      expect(conversion.fileName, 'barua.odt');

      final names = ZipDecoder()
          .decodeBytes(conversion.bytes)
          .files
          .map((f) => f.name)
          .toList();
      expect(names.first, 'mimetype');
      expect(
        names,
        containsAll(['content.xml', 'styles.xml', 'META-INF/manifest.xml']),
      );

      final content = packageText(conversion.bytes, 'content.xml');
      expect(content, contains('office:document-content'));
      expect(content, contains('INVOICE DS-2026-014'));
      // The written ODT must be readable by our own reader.
      final reread = readOfficeDocument(conversion.bytes);
      expect(reread.format, OfficeFormat.odt);
      expect(reread.plainText, contains('INVOICE DS-2026-014'));
    });

    test('XLSX → ODS round-trips through the reader', () async {
      final engine = OfficeEngine();
      final routes = await engine.routesFor(OfficeFormat.xlsx);
      final route = routes.firstWhere((r) => r.to == OfficeFormat.ods);
      final conversion = await engine.convert(
        bytes: xlsxFixture(),
        route: route,
        sourceName: 'daftari.xlsx',
      );
      final reread = readOfficeDocument(conversion.bytes);
      expect(reread.sheetNames, contains('Stock'));
      expect(reread.tableText, contains('Notebook'));
    });

    test('HTML → PDF and TXT → PDF both produce valid PDFs', () async {
      final engine = OfficeEngine();
      for (final entry in [
        (OfficeFormat.html, htmlFixture(), 'note.html'),
        (
          OfficeFormat.txt,
          Uint8List.fromList(utf8.encode('Hello\nWorld')),
          'a.txt',
        ),
      ]) {
        final routes = await engine.routesFor(entry.$1);
        final route = routes.firstWhere((r) => r.to == OfficeFormat.pdf);
        final conversion = await engine.convert(
          bytes: entry.$2,
          route: route,
          sourceName: entry.$3,
        );
        expect(
          latin1.decode(conversion.bytes.sublist(0, 5)),
          '%PDF-',
          reason: '${entry.$3} should become a PDF',
        );
      }
    });

    test('an external engine failure is surfaced, never faked', () async {
      final engine = OfficeEngine(external: _BrokenLibreOffice());
      final routes = await engine.routesFor(OfficeFormat.doc);
      expect(routes, isNotEmpty);
      await expectLater(
        engine.convert(
          bytes: legacyOleFixture(),
          route: routes.first,
          sourceName: 'old.doc',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('invalid output from an external engine is discarded', () async {
      final engine = OfficeEngine(external: _WrongOutputLibreOffice());
      final routes = await engine.routesFor(OfficeFormat.doc);
      await expectLater(
        engine.convert(
          bytes: legacyOleFixture(),
          route: routes.first,
          sourceName: 'old.doc',
        ),
        throwsFormatException,
      );
    });
  });

  group('source preservation', () {
    test('the input bytes are never mutated by a conversion', () async {
      final source = docxFixture();
      final before = Uint8List.fromList(source);
      final engine = OfficeEngine();
      final route = (await engine.routesFor(OfficeFormat.docx))
          .firstWhere((r) => r.id == 'DOCX→PDF');
      await engine.convert(bytes: source, route: route, sourceName: 'x.docx');
      expect(source, before);
    });

    test(
      'output names are derived safely from arbitrary source names',
      () async {
        final engine = OfficeEngine();
        final route = (await engine.routesFor(OfficeFormat.docx))
            .firstWhere((r) => r.id == 'DOCX→PDF');
        final conversion = await engine.convert(
          bytes: docxFixture(),
          route: route,
          sourceName: '../../etc/päss wörd-01.docx',
        );
        // Non-ASCII and path separators are stripped from the output name.
        expect(conversion.fileName, 'pss wrd-01.pdf');
        expect(conversion.fileName, isNot(contains('/')));
      },
    );
  });
}

class _FakeLibreOffice implements ExternalOfficeEngine {
  @override
  String get label => 'LibreOffice (test)';
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<Uint8List> convert({
    required Uint8List bytes,
    required String inputExtension,
    required OfficeFormat to,
  }) async => Uint8List.fromList(utf8.encode('%PDF-1.7\n%%EOF'));
}

class _BrokenLibreOffice extends _FakeLibreOffice {
  @override
  Future<Uint8List> convert({
    required Uint8List bytes,
    required String inputExtension,
    required OfficeFormat to,
  }) async => throw StateError('soffice exited with code 1');
}

class _WrongOutputLibreOffice extends _FakeLibreOffice {
  @override
  Future<Uint8List> convert({
    required Uint8List bytes,
    required String inputExtension,
    required OfficeFormat to,
  }) async => Uint8List.fromList(utf8.encode('not a pdf'));
}
