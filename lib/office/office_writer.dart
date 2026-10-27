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

/// Writes a genuine minimal OOXML Word document. Readable text, headings,
/// paragraph emphasis, tables and page breaks are preserved; unsupported
/// source layout, images, comments, fields, macros and embedded objects are not.
Uint8List writeDocx(OfficeDocument document) {
  final body = StringBuffer();
  for (final block in document.blocks) {
    switch (block.kind) {
      case OfficeBlockKind.paragraph:
        final level = block.headingLevel.clamp(0, 3);
        final style = level > 0
            ? '<w:pPr><w:pStyle w:val="Heading$level"/></w:pPr>'
            : '';
        body.write('<w:p>$style${_docxRuns(block.text, bold: block.bold, italic: block.italic)}</w:p>');
      case OfficeBlockKind.row:
        body.write('<w:tbl><w:tblPr><w:tblBorders>'
            '<w:top w:val="single" w:sz="4" w:space="0" w:color="B7B7B7"/>'
            '<w:left w:val="single" w:sz="4" w:space="0" w:color="B7B7B7"/>'
            '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="B7B7B7"/>'
            '<w:right w:val="single" w:sz="4" w:space="0" w:color="B7B7B7"/>'
            '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="B7B7B7"/>'
            '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="B7B7B7"/>'
            '</w:tblBorders></w:tblPr>');
        body.write('<w:tr>');
        if (block.header) body.write('<w:trPr><w:tblHeader/></w:trPr>');
        for (final cell in block.cells) {
          body.write('<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>'
              '<w:p>${_docxRuns(cell, bold: block.header)}</w:p></w:tc>');
        }
        body.write('</w:tr></w:tbl>');
      case OfficeBlockKind.pageBreak:
        body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
    }
  }
  if (document.blocks.isEmpty) body.write('<w:p/>');
  final entries = <String, String>{
    '[Content_Types].xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''',
    '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''',
    'word/document.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>''',
    'word/_rels/document.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''',
    'word/styles.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:sz w:val="22"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/></w:pPr><w:rPr><w:b/><w:sz w:val="34"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>
</w:styles>''',
    'docProps/core.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>${_escape(document.title)}</dc:title><dc:creator>ZamCan</dc:creator><cp:lastModifiedBy>DeskSuite</cp:lastModifiedBy></cp:coreProperties>''',
    'docProps/app.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>DeskSuite</Application></Properties>''',
  };
  return _zipOfficeEntries(entries);
}

/// Writes a genuine OOXML spreadsheet with inline-string cells. The export
/// preserves readable cell values, not formulas, charts, styles or macros.
Uint8List writeXlsx(OfficeDocument document) {
  final sheets = <String, List<List<String>>>{};
  final usedNames = <String>{};
  String uniqueName(String raw) {
    var base = raw.replaceAll(RegExp(r'[\\[\\]:*?/\\\\]'), '_').trim();
    if (base.isEmpty) base = 'Sheet';
    if (base.length > 31) base = base.substring(0, 31);
    var candidate = base;
    var suffix = 2;
    while (usedNames.contains(candidate.toLowerCase())) {
      final tail = '_$suffix';
      final prefixLength = 31 - tail.length;
      candidate = '${base.substring(0, base.length > prefixLength ? prefixLength : base.length)}$tail';
      suffix++;
    }
    usedNames.add(candidate.toLowerCase());
    return candidate;
  }

  var current = uniqueName(document.sheetNames.isNotEmpty
      ? document.sheetNames.first
      : 'Sheet1');
  sheets[current] = <List<String>>[];
  for (final block in document.blocks) {
    if (block.kind == OfficeBlockKind.paragraph &&
        block.bold &&
        block.headingLevel == 0 &&
        block.text.trim().isNotEmpty) {
      final wanted = block.text.trim();
      final existing = sheets.keys.firstWhere(
        (name) => name.toLowerCase() == wanted.toLowerCase(),
        orElse: () => '',
      );
      current = existing.isNotEmpty ? existing : uniqueName(wanted);
      sheets.putIfAbsent(current, () => <List<String>>[]);
    } else if (block.kind == OfficeBlockKind.row) {
      sheets.putIfAbsent(current, () => <List<String>>[]).add(block.cells);
    }
  }
  if (sheets.isEmpty || sheets.values.every((rows) => rows.isEmpty)) {
    sheets
      ..clear()
      ..['Sheet1'] = <List<String>>[
        <String>[''],
      ];
  }

  String columnName(int index) {
    var n = index;
    var result = '';
    while (n > 0) {
      final remainder = (n - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      n = (n - 1) ~/ 26;
    }
    return result;
  }

  final entries = <String, String>{
    '[Content_Types].xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
${List.generate(sheets.length, (i) => '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}
</Types>''',
    '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>''',
    'xl/workbook.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${sheets.keys.toList().asMap().entries.map((entry) => '<sheet name="${_escape(entry.value)}" sheetId="${entry.key + 1}" r:id="rId${entry.key + 1}"/>').join()}</sheets></workbook>''',
    'xl/_rels/workbook.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${List.generate(sheets.length, (i) => '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>').join()}</Relationships>''',
    'docProps/core.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>${_escape(document.title)}</dc:title><dc:creator>ZamCan</dc:creator></cp:coreProperties>''',
  };
  var sheetIndex = 0;
  for (final entry in sheets.entries) {
    sheetIndex++;
    final rows = StringBuffer();
    final contentRows = entry.value.isEmpty ? <List<String>>[<String>['']] : entry.value;
    for (var rowIndex = 0; rowIndex < contentRows.length; rowIndex++) {
      rows.write('<row r="${rowIndex + 1}">');
      final row = contentRows[rowIndex].isEmpty ? <String>[''] : contentRows[rowIndex];
      for (var colIndex = 0; colIndex < row.length; colIndex++) {
        final ref = '${columnName(colIndex + 1)}${rowIndex + 1}';
        rows.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_escape(row[colIndex])}</t></is></c>');
      }
      rows.write('</row>');
    }
    entries['xl/worksheets/sheet$sheetIndex.xml'] =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$rows</sheetData></worksheet>''';
  }
  return _zipOfficeEntries(entries);
}

String _docxRuns(String value, {bool bold = false, bool italic = false}) {
  final pieces = value.split('\n');
  final result = StringBuffer();
  for (var i = 0; i < pieces.length; i++) {
    if (i > 0) result.write('<w:r><w:br/></w:r>');
    final properties = StringBuffer();
    if (bold) properties.write('<w:b/>');
    if (italic) properties.write('<w:i/>');
    final rPr = properties.isEmpty ? '' : '<w:rPr>$properties</w:rPr>';
    result.write('<w:r>$rPr<w:t xml:space="preserve">${_escape(pieces[i])}</w:t></w:r>');
  }
  return result.toString();
}

Uint8List _zipOfficeEntries(Map<String, String> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = utf8.encode(entry.value);
    archive.add(ArchiveFile(entry.key, bytes.length, bytes));
  }
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
