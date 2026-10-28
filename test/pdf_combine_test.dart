import 'dart:typed_data';

import 'package:desksuite/pdf/pdf_combine.dart';
import 'package:desksuite/pdf/pdf_inspection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a real PDF with distinguishable text, so the merge is tested against
/// bytes the app's own writer produces rather than a fixture blob.
Future<Uint8List> _pdf({int pages = 1, String label = 'doc'}) async {
  final document = pw.Document();
  for (var i = 0; i < pages; i++) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Text('$label page ${i + 1}'),
      ),
    );
  }
  return document.save();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('combinePdfs', () {
    test('joins documents in the order given and reports every page', () async {
      final cover = await _pdf(pages: 1, label: 'cover');
      final report = await _pdf(pages: 3, label: 'report');
      final result = combinePdfs([cover, report]);

      expect(result.documentCount, 2);
      expect(result.sourcePageCounts, [1, 3]);
      expect(result.pageCount, 4);
      expect(result.inspection.pageCount, 4);
      // The returned bytes are a real PDF, not the first input passed through.
      expect(looksLikePdf(result.bytes), isTrue);
      expect(result.bytes.length, greaterThan(cover.length));
    });

    test('order matters: A then B is not B then A page-wise', () async {
      final a = await _pdf(pages: 2, label: 'a');
      final b = await _pdf(pages: 1, label: 'b');
      expect(combinePdfs([a, b]).sourcePageCounts, [2, 1]);
      expect(combinePdfs([b, a]).sourcePageCounts, [1, 2]);
    });

    test('does not modify the source bytes', () async {
      final first = await _pdf(pages: 1, label: 'first');
      final second = await _pdf(pages: 2, label: 'second');
      final firstCopy = Uint8List.fromList(first);
      final secondCopy = Uint8List.fromList(second);
      combinePdfs([first, second]);
      expect(first, firstCopy);
      expect(second, secondCopy);
    });

    test('joins three documents into one file', () async {
      final sources = [
        await _pdf(pages: 1, label: 'one'),
        await _pdf(pages: 2, label: 'two'),
        await _pdf(pages: 3, label: 'three'),
      ];
      final result = combinePdfs(sources);
      expect(result.documentCount, 3);
      expect(result.pageCount, 6);
      expect(result.inspection.pageCount, 6);
    });

    test('refuses a single document with a reason the user can act on', () {
      expect(
        () => combinePdfs([]),
        throwsA(
          isA<PdfCombineFailure>().having(
            (failure) => failure.message,
            'message',
            contains('at least two'),
          ),
        ),
      );
    });

    test(
      'names the file that is not a PDF instead of blaming the merge',
      () async {
        final real = await _pdf();
        final notPdf = Uint8List.fromList('just text'.codeUnits);
        expect(
          () => combinePdfs([real, notPdf]),
          throwsA(
            isA<PdfCombineFailure>().having(
              (failure) => failure.message,
              'message',
              allOf(contains('File 2'), contains('not a PDF')),
            ),
          ),
        );
      },
    );

    test('refuses an empty file', () async {
      final real = await _pdf();
      expect(
        () => combinePdfs([real, Uint8List(0)]),
        throwsA(
          isA<PdfCombineFailure>().having(
            (failure) => failure.message,
            'message',
            allOf(contains('File 2'), contains('empty')),
          ),
        ),
      );
    });

    test('combinedPdfName sanitises and never collides with an input', () {
      expect(
        combinedPdfName('/sdcard/Download/My Report.pdf'),
        'My-Report-combined.pdf',
      );
      expect(combinedPdfName('../../etc/passwd'), 'passwd-combined.pdf');
      expect(combinedPdfName('...pdf'), 'document-combined.pdf');
      expect(combinedPdfName('scan'), 'scan-combined.pdf');
    });
  });
}
