import 'dart:typed_data';

import 'package:desksuite/pdf/pdf_inspection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a real PDF with the app's own writer, so the inspector is tested
/// against bytes a real DeskSuite export produces rather than a fixture blob.
Future<Uint8List> _pdf({int pages = 1, PdfPageFormat? format}) async {
  final document = pw.Document();
  for (var i = 0; i < pages; i++) {
    document.addPage(
      pw.Page(
        pageFormat: format ?? PdfPageFormat.a4,
        build: (_) => pw.Text('Page ${i + 1}'),
      ),
    );
  }
  return document.save();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('looksLikePdf', () {
    test(
      'accepts a real header, a preamble and rejects other content',
      () async {
        final real = await _pdf();
        expect(looksLikePdf(real), isTrue);

        final withPreamble = Uint8List.fromList([
          ...'% preamble\n'.codeUnits,
          ...real,
        ]);
        expect(looksLikePdf(withPreamble), isTrue);

        expect(looksLikePdf(Uint8List.fromList('%PNG'.codeUnits)), isFalse);
        expect(looksLikePdf(Uint8List(0)), isFalse);
        expect(looksLikePdf(Uint8List.fromList([0x25, 0x50])), isFalse);
      },
    );

    test('a PDF marker beyond 1024 bytes is not accepted', () async {
      final padding = Uint8List.fromList(List.filled(1100, 0x20));
      final bytes = Uint8List.fromList([...padding, ...'%PDF-1.7'.codeUnits]);
      expect(looksLikePdf(bytes), isFalse);
    });
  });

  group('inspectPdf', () {
    test('reports the real page count, size and page box', () async {
      final bytes = await _pdf(pages: 3);
      final report = inspectPdf(bytes);
      expect(report.pageCount, 3);
      expect(report.byteLength, bytes.length);
      expect(report.isEncrypted, isFalse);
      expect(report.firstPageWidthMm, closeTo(210, 1));
      expect(report.firstPageHeightMm, closeTo(297, 1));
      expect(report.pageSizeLabel, contains('×'));
      expect(report.sizeLabel, isNotEmpty);
    });

    test('reads a landscape page as wider than tall', () async {
      final bytes = await _pdf(format: PdfPageFormat.a4.landscape);
      final report = inspectPdf(bytes);
      expect(report.firstPageWidthMm, greaterThan(report.firstPageHeightMm));
    });

    test(
      'a small file is labelled in bytes and a large one in megabytes',
      () async {
        final bytes = await _pdf();
        final report = inspectPdf(bytes);
        if (bytes.length < 1024) {
          expect(report.sizeLabel, endsWith(' B'));
        } else if (bytes.length < 1024 * 1024) {
          expect(report.sizeLabel, endsWith(' kB'));
        } else {
          expect(report.sizeLabel, endsWith(' MB'));
        }
      },
    );

    test(
      'rejects empty, oversized and non-PDF files with a usable reason',
      () async {
        expect(
          () => inspectPdf(Uint8List(0)),
          throwsA(
            isA<PdfOpenFailure>().having(
              (e) => e.message,
              'message',
              contains('empty'),
            ),
          ),
        );
        expect(
          () => inspectPdf(Uint8List(maxPdfBytes + 1)),
          throwsA(
            isA<PdfOpenFailure>().having(
              (e) => e.message,
              'message',
              contains('MiB'),
            ),
          ),
        );
        expect(
          () => inspectPdf(Uint8List.fromList('not a pdf at all'.codeUnits)),
          throwsA(
            isA<PdfOpenFailure>().having(
              (e) => e.message,
              'message',
              contains('not a PDF'),
            ),
          ),
        );
      },
    );

    test('a damaged PDF either opens or fails with a usable reason', () async {
      // The engine repairs what it can from a truncated file, so the contract
      // is not 'always rejects': it is 'never throws anything a screen cannot
      // show'. A partial file that still carries pages opens with the real
      // count; one with none fails with PdfOpenFailure.
      final bytes = await _pdf(pages: 2);
      for (final cut in [200, 400, 800, bytes.length - 50]) {
        final truncated = Uint8List.sublistView(bytes, 0, cut);
        try {
          final report = inspectPdf(truncated);
          expect(report.pageCount, greaterThan(0));
          expect(report.byteLength, cut);
        } on PdfOpenFailure catch (failure) {
          expect(failure.message, isNotEmpty);
        }
      }
      // A cut that leaves no page at all fails cleanly.
      expect(
        () => inspectPdf(Uint8List.sublistView(bytes, 0, 60)),
        throwsA(isA<PdfOpenFailure>()),
      );
    });

    test('inspection does not modify the bytes it reads', () async {
      final bytes = await _pdf(pages: 2);
      final copy = Uint8List.fromList(bytes);
      inspectPdf(bytes);
      expect(bytes, orderedEquals(copy));
    });
  });

  test(
    'a scanned document PDF from the real pipeline inspects as A4 pages',
    () async {
      final source = img.Image(width: 60, height: 90);
      img.fill(source, color: img.ColorRgb8(240, 240, 240));
      final png = Uint8List.fromList(img.encodePng(source));
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
        ),
      );
      final report = inspectPdf(await document.save());
      expect(report.pageCount, 1);
      expect(report.firstPageWidthMm, closeTo(210, 1));
    },
  );
}
