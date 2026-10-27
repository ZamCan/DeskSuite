import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'office_reader.dart';

const _manifestXml = '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
<manifest:file-entry manifest:full-path="/" manifest:version="1.2" manifest:media-type="%MEDIA%"/>
<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
<manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
<manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/>
</manifest:manifest>''';

const _stylesXml = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" office:version="1.2">
<office:styles>
<style:style style:name="Standard" style:family="paragraph"><style:paragraph-properties fo:margin-bottom="0.25cm"/><style:text-properties fo:font-size="11pt"/></style:style>
<style:style style:name="Heading_20_1" style:family="paragraph"><style:text-properties fo:font-size="17pt" fo:font-weight="bold"/></style:style>
<style:style style:name="Heading_20_2" style:family="paragraph"><style:text-properties fo:font-size="14pt" fo:font-weight="bold"/></style:style>
<style:style style:name="Heading_20_3" style:family="paragraph"><style:text-properties fo:font-size="12pt" fo:font-weight="bold"/></style:style>
</office:styles>
</office:document-styles>''';

/// Writes a genuine OpenDocument text package that LibreOffice, Word and
/// Google Docs can open. Content is the same readable model the PDF renderer
/// uses, so nothing is invented.
Uint8List writeOdt(OfficeDocument document) {
  final body = StringBuffer();
  for (final block in document.blocks) {
    switch (block.kind) {
      case OfficeBlockKind.row:
        body.write('<text:p>${_escape(block.cells.join('  |  '))}</text:p>');
      case OfficeBlockKind.pageBreak:
        body.write('<text:p><text:soft-page-break/></text:p>');
      case OfficeBlockKind.paragraph:
        final level = block.headingLevel.clamp(0, 3);
        final styleAttribute = level > 0
            ? ' text:style-name="Heading_20_$level"'
            : '';
        body.write('<text:p$styleAttribute>${_escape(block.text)}</text:p>');
    }
  }
  final content =
      '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" office:version="1.2">
<office:body><office:text>$body</office:text></office:body>
</office:document-content>''';
  return _package(
    mediaType: 'application/vnd.oasis.opendocument.text',
    content: content,
    title: document.title,
  );
}

/// Writes a genuine OpenDocument spreadsheet with one table per sheet.
Uint8List writeOds(OfficeDocument document) {
  // Bold paragraphs are the sheet headings emitted by the reader.
  final sheets = <String, List<List<String>>>{};
  var current = 'Sheet1';
  for (final block in document.blocks) {
    if (block.kind == OfficeBlockKind.paragraph) {
      if (block.bold && block.headingLevel == 0 && block.text.isNotEmpty) {
        current = block.text;
        sheets.putIfAbsent(current, () => <List<String>>[]);
      }
    } else if (block.kind == OfficeBlockKind.row) {
      sheets.putIfAbsent(current, () => <List<String>>[]).add(block.cells);
    }
  }
  if (sheets.isEmpty || sheets.values.every((rows) => rows.isEmpty)) {
    sheets['Sheet1'] = <List<String>>[
      <String>[''],
    ];
  }
  final body = StringBuffer();
  for (final entry in sheets.entries) {
    body.write('<table:table table:name="${_escape(entry.key)}">');
    if (entry.value.isEmpty) {
      body.write(
        '<table:table-row><table:table-cell>'
        '<text:p></text:p></table:table-cell></table:table-row>',
      );
    }
    for (final row in entry.value) {
      body.write('<table:table-row>');
      for (final cell in row) {
        body.write(
          '<table:table-cell office:value-type="string">'
          '<text:p>${_escape(cell)}</text:p></table:table-cell>',
        );
      }
      body.write('</table:table-row>');
    }
    body.write('</table:table>');
  }
  final content =
      '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" office:version="1.2">
<office:body><office:spreadsheet>$body</office:spreadsheet></office:body>
</office:document-content>''';
  return _package(
    mediaType: 'application/vnd.oasis.opendocument.spreadsheet',
    content: content,
    title: document.title,
  );
}

Uint8List _package({
  required String mediaType,
  required String content,
  required String title,
}) {
  final archive = Archive();
  void add(String name, String value) {
    final bytes = utf8.encode(value);
    archive.add(ArchiveFile(name, bytes.length, bytes));
  }

  // The mimetype entry must come first and stay uncompressed for maximum
  // compatibility with OpenDocument consumers.
  add('mimetype', mediaType);
  add('content.xml', content);
  add('styles.xml', _stylesXml);
  add(
    'meta.xml',
    '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:'
        'xmlns:office:1.0" xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" '
        'office:version="1.2"><office:meta><dc:title>${_escape(title)}</dc:title>'
        '<meta:generator>DeskSuite (ZamCan)</meta:generator></office:meta>'
        '</office:document-meta>',
  );
  add('META-INF/manifest.xml', _manifestXml.replaceAll('%MEDIA%', mediaType));
  return ZipEncoder().encodeBytes(archive);
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Converts HTML to readable plain text: block elements become paragraphs,
/// list items become bullets and tags/scripts/styles are dropped.
String htmlToText(Uint8List bytes) {
  var html = utf8.decode(bytes, allowMalformed: true);
  html = html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'</(p|div|h[1-6]|tr|li|section|article)>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<td[^>]*>', caseSensitive: false), '\t')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  html = html
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  final lines = html
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+$'), '').trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return lines.isEmpty ? '' : '${lines.join('\n\n')}\n';
}
