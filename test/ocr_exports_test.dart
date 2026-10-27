import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:desksuite/ocr/ocr_engine.dart';
import 'package:desksuite/ocr/text_exports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeOcrText', () {
    test('trims trailing spaces and collapses blank runs', () {
      const raw = '  First line  \n\n\n\nSecond\t\n   \n';
      expect(normalizeOcrText(raw), '  First line\n\nSecond\n');
    });

    test('normalizes CRLF and CR to LF', () {
      expect(normalizeOcrText('a\r\nb\rc'), 'a\nb\nc\n');
    });

    test('returns empty string for whitespace-only input', () {
      expect(normalizeOcrText('   \n\n\t'), '');
    });
  });

  group('buildPlainText', () {
    test('is UTF-8 with a single trailing newline', () {
      final bytes = buildPlainText('Habari\nDunia');
      expect(utf8.decode(bytes), 'Habari\nDunia\n');
    });
  });

  group('buildDocx', () {
    test('produces a valid package with one paragraph per line', () {
      final bytes = buildDocx('First paragraph\n\nThird & <last>');
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toList();
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('_rels/.rels'));
      expect(names, contains('word/document.xml'));

      final document = utf8.decode(
        archive.files.firstWhere((f) => f.name == 'word/document.xml').content
            as List<int>,
      );
      expect(document, contains('First paragraph'));
      // Escaped, never injected raw.
      expect(document, contains('Third &amp; &lt;last&gt;'));
      expect(document, isNot(contains('<last>')));
      // Blank line becomes an empty paragraph rather than being dropped.
      expect('<w:p/>'.allMatches(document).length, 1);
      expect(RegExp('<w:p>').allMatches(document).length, 2);
    });

    test('escapes quotes and apostrophes in the title', () {
      final bytes = buildDocx('body', title: 'A "quoted" owner\'s file');
      final archive = ZipDecoder().decodeBytes(bytes);
      final core = utf8.decode(
        archive.files.firstWhere((f) => f.name == 'docProps/core.xml').content
            as List<int>,
      );
      expect(core, contains('&quot;quoted&quot;'));
      expect(core, contains('&apos;'));
    });

    test('empty text still yields an openable document', () {
      final archive = ZipDecoder().decodeBytes(buildDocx('   '));
      expect(archive.files.map((f) => f.name), contains('word/document.xml'));
    });
  });

  group('exportHeader', () {
    test('states the engine and confidence honestly', () {
      const result = OcrResult(
        text: 'x',
        words: <OcrWord>[
          OcrWord(
            text: 'x',
            left: 0,
            top: 0,
            right: 5,
            bottom: 5,
            confidence: 82,
          ),
        ],
        imageWidth: 10,
        imageHeight: 10,
        language: 'eng',
        meanConfidence: 82,
      );
      final header = exportHeader(result);
      expect(header, contains('Tesseract'));
      expect(header, contains('82%'));
      expect(header.toLowerCase(), contains('review'));
    });

    test('is empty when nothing was recognized', () {
      expect(exportHeader(OcrResult.empty), '');
    });
  });
}
