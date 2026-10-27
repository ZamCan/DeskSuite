import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds genuine office packages for tests so the readers are exercised against
/// real OOXML/ODF containers rather than hand-written stubs.
class OfficeFixture {
  final List<ArchiveFile> _files = [];

  void add(String name, String content) {
    final bytes = utf8.encode(content);
    _files.add(ArchiveFile(name, bytes.length, bytes));
  }

  void addRaw(String name, List<int> bytes) {
    _files.add(ArchiveFile(name, bytes.length, bytes));
  }

  Uint8List build() {
    final archive = Archive();
    for (final file in _files) {
      archive.add(file);
    }
    return ZipEncoder().encodeBytes(archive);
  }
}

const _wordNs =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// A DOCX with a heading, bold run, a table and an explicit page break.
Uint8List docxFixture({
  String heading = 'INVOICE DS-2026-014',
  String body = 'Prepared for ZamCan Stationery.',
  String tableCell = 'A4 paper',
  bool withPageBreak = true,
  String title = 'Sample invoice',
}) {
  final fixture = OfficeFixture()
    ..add(
      '[Content_Types].xml',
      '<?xml version="1.0"?><Types '
          'xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Override PartName="/word/document.xml" ContentType="application/vnd.'
          'openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
          '</Types>',
    )
    ..add(
      'word/document.xml',
      '<?xml version="1.0"?><w:document $_wordNs><w:body>'
          '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>$heading</w:t></w:r></w:p>'
          '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Total:</w:t></w:r><w:r><w:t xml:space="preserve"> 5,000 TZS</w:t></w:r></w:p>'
          '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Item</w:t></w:r></w:p></w:tc>'
          '<w:tc><w:p><w:r><w:t>Qty</w:t></w:r></w:p></w:tc></w:tr>'
          '<w:tr><w:tc><w:p><w:r><w:t>$tableCell</w:t></w:r></w:p></w:tc>'
          '<w:tc><w:p><w:r><w:t>2</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
          '<w:p><w:r><w:t>$body</w:t></w:r></w:p>'
          '${withPageBreak ? '<w:p><w:r><w:br w:type="page"/></w:r></w:p><w:p><w:r><w:t>Appendix page</w:t></w:r></w:p>' : ''}'
          '<w:sectPr/></w:body></w:document>',
    )
    ..add(
      'docProps/core.xml',
      '<?xml version="1.0"?><cp:coreProperties '
          'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
          'xmlns:dc="http://purl.org/dc/elements/1.1/">'
          '<dc:title>$title</dc:title></cp:coreProperties>',
    );
  return fixture.build();
}

/// An XLSX with shared strings, a number, a formula and a boolean.
Uint8List xlsxFixture() {
  final fixture = OfficeFixture()
    ..add(
      'xl/workbook.xml',
      '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/'
          'officeDocument/2006/relationships"><sheets>'
          '<sheet name="Stock" sheetId="1" r:id="rId1"/>'
          '<sheet name="Sales" sheetId="2" r:id="rId2"/>'
          '</sheets></workbook>',
    )
    ..add(
      'xl/_rels/workbook.xml.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats'
          '.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Type="worksheet" Target="worksheets/sheet2.xml"/>'
          '</Relationships>',
    )
    ..add(
      'xl/sharedStrings.xml',
      '<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main"><si><t>Notebook</t></si><si><t>Price, TZS</t></si></sst>',
    )
    ..add(
      'xl/worksheets/sheet1.xml',
      '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main"><sheetData>'
          '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
          '<row r="2"><c r="A2" t="s"><v>0</v></c><c r="B2"><v>3500</v></c></row>'
          '<row r="3"><c r="A3"><f>SUM(B2:B2)</f><v>3500</v></c><c r="B3" t="b"><v>1</v></c></row>'
          '</sheetData></worksheet>',
    )
    ..add(
      'xl/worksheets/sheet2.xml',
      '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main"><sheetData>'
          '<row r="1"><c r="A1" t="inlineStr"><is><t>Counter sales</t></is></c></row>'
          '</sheetData></worksheet>',
    );
  return fixture.build();
}

Uint8List pptxFixture() {
  final fixture = OfficeFixture()
    ..add(
      'ppt/presentation.xml',
      '<?xml version="1.0"?><p:presentation xmlns:p="http://schemas.'
          'openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.'
          'openxmlformats.org/officeDocument/2006/relationships"/>',
    )
    ..add(
      'ppt/_rels/presentation.xml.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats'
          '.org/package/2006/relationships">'
          '<Relationship Id="rId2" Type="slide" Target="slides/slide2.xml"/>'
          '<Relationship Id="rId1" Type="slide" Target="slides/slide1.xml"/>'
          '</Relationships>',
    )
    ..add(
      'ppt/slides/slide1.xml',
      '<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/'
          'presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/'
          'drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody>'
          '<a:p><a:r><a:t>Welcome to DeskSuite</a:t></a:r></a:p>'
          '<a:p><a:r><a:t>Scan, edit, print.</a:t></a:r></a:p>'
          '</p:txBody></p:sp></p:spTree></p:cSld></p:sld>',
    )
    ..add(
      'ppt/slides/slide2.xml',
      '<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/'
          'presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/'
          'drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody>'
          '<a:p><a:r><a:t>Stationery catalogue</a:t></a:r></a:p>'
          '</p:txBody></p:sp></p:spTree></p:cSld></p:sld>',
    );
  return fixture.build();
}

Uint8List odtFixture() {
  final fixture = OfficeFixture()
    ..add('mimetype', 'application/vnd.oasis.opendocument.text')
    ..add(
      'content.xml',
      '<?xml version="1.0"?><office:document-content '
          'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
          'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">'
          '<office:body><office:text>'
          '<text:h text:outline-level="1">Barua rasmi</text:h>'
          '<text:p>Habari <text:span>mfanyakazi</text:span>, karibu DeskSuite.</text:p>'
          '<text:p>Mstari wa pili.</text:p>'
          '</office:text></office:body></office:document-content>',
    );
  return fixture.build();
}

Uint8List odsFixture() {
  final fixture = OfficeFixture()
    ..add('mimetype', 'application/vnd.oasis.opendocument.spreadsheet')
    ..add(
      'content.xml',
      '<?xml version="1.0"?><office:document-content '
          'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
          'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
          'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0">'
          '<office:body><office:spreadsheet>'
          '<table:table table:name="Daftari">'
          '<table:table-row><table:table-cell><text:p>Bidhaa</text:p></table:table-cell>'
          '<table:table-cell><text:p>Bei</text:p></table:table-cell></table:table-row>'
          '<table:table-row><table:table-cell><text:p>Kalamu</text:p></table:table-cell>'
          '<table:table-cell><text:p>500</text:p></table:table-cell></table:table-row>'
          '</table:table></office:spreadsheet></office:body></office:document-content>',
    );
  return fixture.build();
}

Uint8List odfZipBombFixture() {
  // 4000+ entries exceed the reader's guard without needing huge real content.
  final fixture = OfficeFixture()
    ..add('mimetype', 'application/vnd.oasis.opendocument.text');
  for (var i = 0; i < 4100; i++) {
    fixture.add('junk/$i.xml', '<x/>');
  }
  return fixture.build();
}

Uint8List odfNotAnOfficeDoc() {
  final fixture = OfficeFixture()..add('readme.txt', 'hello');
  return fixture.build();
}

Uint8List legacyOleFixture() {
  const header = [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1];
  return Uint8List.fromList([...header, ...List<int>.filled(504, 0)]);
}

Uint8List rtfFixture() => Uint8List.fromList(
  utf8.encode(
    r'{\rtf1\ansi{\fonttbl{\f0 Times}}\f0 '
    r'Kumbuka\par Mstari wa pili.\par}',
  ),
);

Uint8List htmlFixture() => Uint8List.fromList(
  utf8.encode('<!doctype html><html><body><h1>Risiti</h1></body></html>'),
);
