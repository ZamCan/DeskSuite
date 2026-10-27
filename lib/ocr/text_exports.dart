import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'ocr_engine.dart';

/// Normalizes recognized text for export: trims trailing spaces per line,
/// collapses runs of blank lines and always ends with a single newline.
String normalizeOcrText(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+$'), ''))
      .toList();
  final output = <String>[];
  var blankRun = 0;
  for (final line in lines) {
    if (line.trim().isEmpty) {
      blankRun++;
      if (blankRun > 1) continue;
      output.add('');
    } else {
      blankRun = 0;
      output.add(line);
    }
  }
  while (output.isNotEmpty && output.first.isEmpty) {
    output.removeAt(0);
  }
  while (output.isNotEmpty && output.last.isEmpty) {
    output.removeLast();
  }
  return output.isEmpty ? '' : '${output.join('\n')}\n';
}

/// UTF-8 plain text, suitable for `.txt` export.
Uint8List buildPlainText(String text) =>
    Uint8List.fromList(utf8.encode(normalizeOcrText(text)));

/// Minimal, valid WordprocessingML package for the recognized text.
///
/// This is deliberately a text-flow document, not a layout reconstruction: each
/// recognized line becomes one paragraph with no invented formatting. The file
/// opens in Word, LibreOffice and Google Docs as an editable document.
Uint8List buildDocx(String text, {String title = 'DeskSuite text'}) {
  final normalized = normalizeOcrText(text);
  final paragraphs = normalized.isEmpty ? <String>[''] : normalized.split('\n');
  // The normalized text ends with a newline; that terminator is not a
  // paragraph of its own.
  if (paragraphs.length > 1 && paragraphs.last.isEmpty) {
    paragraphs.removeLast();
  }
  final body = StringBuffer();
  for (final paragraph in paragraphs) {
    if (paragraph.isEmpty) {
      body.write('<w:p/>');
      continue;
    }
    body.write(
      '<w:p><w:r><w:t xml:space="preserve">'
      '${_escapeXml(paragraph)}'
      '</w:t></w:r></w:p>',
    );
  }

  final documentXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body>
</w:document>''';

  final contentTypes =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>''';

  final relationships =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>''';

  final core =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:title>${_escapeXml(title)}</dc:title><dc:creator>DeskSuite (ZamCan)</dc:creator>
</cp:coreProperties>''';

  final archive = Archive();
  void add(String name, String xml) {
    final bytes = utf8.encode(xml);
    archive.add(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', contentTypes);
  add('_rels/.rels', relationships);
  add('word/document.xml', documentXml);
  add('docProps/core.xml', core);

  return ZipEncoder().encodeBytes(archive);
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Text plus a short provenance line, used for exports that must state their
/// engine and confidence honestly.
String exportHeader(OcrResult result) {
  if (result.isEmpty) return '';
  final confidence = result.meanConfidence;
  final scored = confidence == null
      ? 'confidence not reported'
      : 'mean word confidence ${confidence.toStringAsFixed(0)}%';
  return 'Recognized by ${result.engineLabel} (${result.language}), $scored.\n'
      'Review before relying on this text; OCR can misread characters.\n';
}
