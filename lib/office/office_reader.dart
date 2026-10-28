import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'office_format.dart';
import 'office_package.dart';

/// Thrown when a document is a supported container but contains content this
/// build cannot represent. The message is shown to the user, so it must say
/// what is lost rather than pretending the conversion was complete.
class OfficeContentUnsupported implements Exception {
  const OfficeContentUnsupported(this.message);
  final String message;
  @override
  String toString() => message;
}

class OfficeBlock {
  const OfficeBlock.paragraph(
    this.text, {
    this.headingLevel = 0,
    this.bold = false,
    this.italic = false,
  }) : kind = OfficeBlockKind.paragraph,
       cells = const [],
       header = false;

  const OfficeBlock.cells(this.cells, {this.header = false})
    : kind = OfficeBlockKind.row,
      text = '',
      headingLevel = 0,
      bold = false,
      italic = false;

  const OfficeBlock.pageBreak()
    : kind = OfficeBlockKind.pageBreak,
      text = '',
      headingLevel = 0,
      bold = false,
      italic = false,
      cells = const [],
      header = false;

  final OfficeBlockKind kind;
  final String text;
  final int headingLevel;
  final bool bold;
  final bool italic;
  final List<String> cells;
  final bool header;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'text': text,
    'heading': headingLevel,
    'bold': bold,
    'italic': italic,
    'cells': cells,
    'header': header,
  };
}

enum OfficeBlockKind { paragraph, row, pageBreak }

/// A readable representation of an office document.
///
/// This is a content model, not a layout reconstruction: it preserves text,
/// paragraph order, heading levels, emphasis and spreadsheet cell values. It
/// deliberately does not claim to preserve exact fonts, floating images,
/// embedded objects, macros or complex layout.
class OfficeDocument {
  const OfficeDocument({
    required this.format,
    required this.title,
    required this.blocks,
    this.sheetNames = const [],
    this.slideCount = 0,
    this.notes = const [],
  });

  final OfficeFormat format;
  final String title;
  final List<OfficeBlock> blocks;
  final List<String> sheetNames;
  final int slideCount;

  /// Honest notes about what was dropped or flattened while reading.
  final List<String> notes;

  String get plainText => blocks
      .where((b) => b.kind == OfficeBlockKind.paragraph)
      .map((b) => b.text)
      .where((t) => t.trim().isNotEmpty)
      .join('\n\n');

  String get tableText => blocks
      .where((b) => b.kind == OfficeBlockKind.row)
      .map((b) => b.cells.join('\t'))
      .join('\n');
}

/// Reads the content of a supported office document. Runs comfortably on the UI
/// isolate for typical documents; call it through [readOfficeInBackground] for
/// user files so a large workbook cannot stall a frame.
OfficeDocument readOfficeDocument(Uint8List bytes, {String? fileName}) =>
    readInspectedOfficeDocument(inspectOfficeFile(bytes, fileName: fileName));

/// Reads an already inspected source without opening and inflating its ZIP
/// parts a second time. The inspection must be used within this operation.
OfficeDocument readInspectedOfficeDocument(OfficeFileInspection inspection) {
  final bytes = inspection.bytes;
  final detected = inspection.detected;
  final package = inspection.package;
  return switch (detected.format) {
    OfficeFormat.docx => _readDocx(package!),
    OfficeFormat.xlsx => _readXlsx(package!),
    OfficeFormat.pptx => _readPptx(package!),
    OfficeFormat.odt => _readOdfText(package!),
    OfficeFormat.ods => _readOdfSheet(package!),
    OfficeFormat.odp => _readOdfPresentation(package!),
    OfficeFormat.rtf => _readRtf(bytes),
    final other => throw OfficeContentUnsupported(
      'This build cannot read ${other.label} content. '
      '${other == OfficeFormat.pdf ? 'Open it with a PDF tool.' : 'Convert it in a compatible external application first.'}',
    ),
  };
}

const _nsWord = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _nsOffice = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
const _nsText = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
const _nsTable = 'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
const _nsRelationships =
    'http://schemas.openxmlformats.org/package/2006/relationships';

XmlElement _root(String xml, {String? part}) {
  try {
    return XmlDocument.parse(xml).rootElement;
  } on XmlException catch (error) {
    throw FormatException(
      'The document part${part == null ? '' : ' "$part"'} is not valid XML: '
      '${error.message}',
    );
  }
}

// ---------------------------------------------------------------- Word (*.docx)

OfficeDocument _readDocx(OfficePackage package) {
  final xml = package.textOf('word/document.xml');
  if (xml == null) {
    throw const FormatException('The DOCX package has no main document part.');
  }
  final root = _root(xml, part: 'word/document.xml');
  final body = _childWithNs(root, _nsWord, 'body');
  if (body == null) {
    throw const FormatException('The DOCX document has no body.');
  }
  final blocks = <OfficeBlock>[];
  final notes = <String>[];
  var sawTable = false;
  var skippedImages = 0;
  var skippedFields = 0;

  void visit(XmlElement element) {
    for (final child in element.childElements) {
      if (child.localName == 'p' && child.namespaceUri == _nsWord) {
        final block = _docxParagraph(child);
        if (block != null) blocks.add(block);
        if (child.getAttribute('pageBreakBefore', namespaceUri: _nsWord) !=
            null) {
          blocks.add(const OfficeBlock.pageBreak());
        }
        if (child.descendants.whereType<XmlElement>().any(
          (e) =>
              e.localName == 'br' &&
              e.namespaceUri == _nsWord &&
              e.getAttribute('type', namespaceUri: _nsWord) == 'page',
        )) {
          blocks.add(const OfficeBlock.pageBreak());
        }
      } else if (child.localName == 'tbl' && child.namespaceUri == _nsWord) {
        sawTable = true;
        for (final row in child.childElements.where(
          (e) => e.localName == 'tr' && e.namespaceUri == _nsWord,
        )) {
          final cells = <String>[];
          for (final cell in row.childElements.where(
            (e) => e.localName == 'tc' && e.namespaceUri == _nsWord,
          )) {
            final text = cell.descendants
                .whereType<XmlElement>()
                .where((e) => e.localName == 't' && e.namespaceUri == _nsWord)
                .map((e) => e.innerText)
                .join(' ')
                .trim();
            cells.add(text);
          }
          blocks.add(OfficeBlock.cells(cells));
        }
      } else if (child.localName == 'drawing' ||
          child.localName == 'pict' ||
          child.localName == 'object') {
        skippedImages++;
      } else if (child.localName == 'sectPr') {
        // Section properties: page size, margins. Not represented in blocks.
      } else {
        visit(child);
      }
    }
  }

  visit(body);
  if (skippedImages > 0) {
    notes.add(
      '$skippedImages embedded image(s) are not carried into the '
      'exported document.',
    );
  }
  if (skippedFields > 0) {
    notes.add('Some fields were flattened to their cached text.');
  }
  if (sawTable) {
    notes.add('Tables are preserved as rows and cells with plain text.');
  }
  return OfficeDocument(
    format: OfficeFormat.docx,
    title: _coreProperty(package, 'title') ?? 'Word document',
    blocks: blocks,
    notes: notes,
  );
}

OfficeBlock? _docxParagraph(XmlElement paragraph) {
  final runs = paragraph.childElements.where(
    (e) => e.localName == 'r' && e.namespaceUri == _nsWord,
  );
  final buffer = StringBuffer();
  var bold = false;
  var italic = false;
  for (final run in runs) {
    final properties = _childWithNs(run, _nsWord, 'rPr');
    if (properties != null) {
      bold = bold || _childWithNs(properties, _nsWord, 'b') != null;
      italic = italic || _childWithNs(properties, _nsWord, 'i') != null;
    }
    for (final node in run.children.whereType<XmlElement>()) {
      if (node.namespaceUri == _nsWord && node.localName == 't') {
        buffer.write(node.innerText);
      } else if (node.localName == 'tab') {
        buffer.write('\t');
      }
    }
  }
  final style = _childWithNs(paragraph, _nsWord, 'pPr');
  var heading = 0;
  if (style != null) {
    final styleElement = _childWithNs(style, _nsWord, 'pStyle');
    final value =
        styleElement?.getAttribute('val', namespaceUri: _nsWord) ?? '';
    final match = RegExp(
      r'^Heading([1-6])$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match != null) heading = int.parse(match.group(1)!);
  }
  final text = buffer.toString();
  if (text.isEmpty && heading == 0) return null;
  return OfficeBlock.paragraph(
    text,
    headingLevel: heading,
    bold: bold,
    italic: italic,
  );
}

String? _coreProperty(OfficePackage package, String localName) {
  final core = package.textOf('docProps/core.xml');
  if (core == null) return null;
  try {
    final value = XmlDocument.parse(core)
        .findAllElements(localName, namespaceUri: '*');
    final text = value.isEmpty ? null : value.first.innerText.trim();
    return (text == null || text.isEmpty) ? null : text;
  } on XmlException {
    return null;
  }
}

XmlElement? _childWithNs(XmlElement parent, String ns, String localName) {
  for (final child in parent.childElements) {
    if (child.localName == localName && child.namespaceUri == ns) return child;
  }
  return null;
}

// ----------------------------------------------------------- Excel (*.xlsx)

OfficeDocument _readXlsx(OfficePackage package) {
  final shared = _xlsxSharedStrings(package);
  final workbookXml = package.textOf('xl/workbook.xml');
  if (workbookXml == null) {
    throw const FormatException('The XLSX package has no workbook part.');
  }
  final workbook = _root(workbookXml, part: 'xl/workbook.xml');
  final relationships = _relationships(package, 'xl/_rels/workbook.xml.rels');
  final sheets = <({String name, String part})>[];
  for (final sheet in workbook.descendants.whereType<XmlElement>().where(
    (e) => e.localName == 'sheet',
  )) {
    final id = sheet.getAttribute('id', namespaceUri: '*') ?? '';
    final relationshipId = sheet.attributes
        .where((a) => a.name.local == 'id')
        .map((a) => a.value)
        .firstOrNull;
    final target = relationships[relationshipId ?? id];
    if (target == null) continue;
    sheets.add((name: sheet.getAttribute('name') ?? 'Sheet', part: target));
  }
  if (sheets.isEmpty) {
    throw const FormatException('The workbook contains no readable sheets.');
  }
  final blocks = <OfficeBlock>[];
  final notes = <String>[];
  final names = <String>[];
  for (final sheet in sheets) {
    final xml = package.textOf(sheet.part);
    if (xml == null) {
      notes.add('Sheet "${sheet.name}" could not be read.');
      continue;
    }
    names.add(sheet.name);
    blocks.add(OfficeBlock.paragraph(sheet.name, bold: true));
    final root = _root(xml, part: sheet.part);
    for (final row in root.descendants.whereType<XmlElement>().where(
      (e) => e.localName == 'row',
    )) {
      final cells = <String>[];
      for (final cell in row.childElements.where((e) => e.localName == 'c')) {
        cells.add(_xlsxCellValue(cell, shared));
      }
      if (cells.every((c) => c.isEmpty)) continue;
      blocks.add(OfficeBlock.cells(cells));
    }
  }
  notes.add(
    'Cached formula results, or formulas without a cached result, are carried as text; formulas are not recalculated. Cell formatting, charts and pivot tables are not preserved.',
  );
  return OfficeDocument(
    format: OfficeFormat.xlsx,
    title: _coreProperty(package, 'title') ?? 'Excel workbook',
    blocks: blocks,
    sheetNames: names,
    notes: notes,
  );
}

Map<String, String> _relationships(OfficePackage package, String part) {
  final xml = package.textOf(part);
  if (xml == null) return const {};
  final root = _root(xml, part: part);
  final map = <String, String>{};
  final source = part.replaceFirst('_rels/', '').replaceFirst('.rels', '');
  for (final relationship in root.childElements.where(
    (e) => e.localName == 'Relationship' && e.namespaceUri == _nsRelationships,
  )) {
    final id = relationship.getAttribute('Id');
    final target = relationship.getAttribute('Target');
    if (id == null || target == null) continue;
    map[id] = package.resolve(from: source, target: target);
  }
  return map;
}

List<String> _xlsxSharedStrings(OfficePackage package) {
  final xml = package.textOf('xl/sharedStrings.xml');
  if (xml == null) return const [];
  final root = _root(xml, part: 'xl/sharedStrings.xml');
  return root.childElements
      .where((e) => e.localName == 'si')
      .map(
        (e) => e.descendants
            .whereType<XmlElement>()
            .where((t) => t.localName == 't')
            .map((t) => t.innerText)
            .join(),
      )
      .toList(growable: false);
}

String _xlsxCellValue(XmlElement cell, List<String> shared) {
  final type = cell.getAttribute('t') ?? 'n';
  final value = cell.childElements
      .where((e) => e.localName == 'v')
      .map((e) => e.innerText)
      .firstOrNull;
  final inline = cell.childElements.where((e) => e.localName == 'is');
  if (type == 'inlineStr' && inline.isNotEmpty) {
    return inline.first.descendants
        .whereType<XmlElement>()
        .where((t) => t.localName == 't')
        .map((t) => t.innerText)
        .join();
  }
  final formula = cell.childElements
      .where((e) => e.localName == 'f')
      .map((e) => e.innerText)
      .firstOrNull;
  if (value == null || value.isEmpty) {
    return formula == null || formula.isEmpty ? '' : '=$formula';
  }
  if (type == 's') {
    final index = int.tryParse(value);
    if (index != null && index >= 0 && index < shared.length) {
      return shared[index];
    }
    return '';
  }
  if (type == 'b') return value == '1' ? 'TRUE' : 'FALSE';
  return value;
}

// ------------------------------------------------------ PowerPoint (*.pptx)

OfficeDocument _readPptx(OfficePackage package) {
  final presentation = package.textOf('ppt/presentation.xml');
  if (presentation == null) {
    throw const FormatException('The PPTX package has no presentation part.');
  }
  final relationships = _relationships(
    package,
    'ppt/_rels/presentation.xml.rels',
  );
  final slideParts = relationships.values
      .where((part) => part.startsWith('ppt/slides/slide'))
      .toList();
  if (slideParts.isEmpty) {
    throw const FormatException(
      'The presentation contains no readable slides.',
    );
  }
  slideParts.sort((a, b) {
    final ai =
        int.tryParse(RegExp(r'(\d+)').firstMatch(a)?.group(1) ?? '0') ?? 0;
    final bi =
        int.tryParse(RegExp(r'(\d+)').firstMatch(b)?.group(1) ?? '0') ?? 0;
    return ai.compareTo(bi);
  });
  final blocks = <OfficeBlock>[];
  var index = 0;
  for (final part in slideParts) {
    final xml = package.textOf(part);
    index++;
    if (xml == null) continue;
    final root = _root(xml, part: part);
    blocks.add(OfficeBlock.paragraph('Slide $index', headingLevel: 2));
    final paragraphs = root.descendants.whereType<XmlElement>().where(
      (e) => e.localName == 'p',
    );
    var added = 0;
    for (final paragraph in paragraphs) {
      final text = paragraph.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 't')
          .map((e) => e.innerText)
          .join()
          .trim();
      if (text.isEmpty) continue;
      blocks.add(OfficeBlock.paragraph(text));
      added++;
    }
    if (added == 0) {
      blocks.add(const OfficeBlock.paragraph('(no text on this slide)'));
    }
  }
  return OfficeDocument(
    format: OfficeFormat.pptx,
    title: _coreProperty(package, 'title') ?? 'PowerPoint presentation',
    blocks: blocks,
    slideCount: slideParts.length,
    notes: [
      'Slide text is carried in reading order. Slide images, animations, '
          'speaker notes and layouts are not reproduced.',
    ],
  );
}

// ------------------------------------------------- OpenDocument text / sheet

OfficeDocument _readOdfText(OfficePackage package) {
  final xml = package.textOf('content.xml');
  if (xml == null) {
    throw const FormatException('The ODT package has no content part.');
  }
  final root = _root(xml, part: 'content.xml');
  final body = root.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'text' && e.namespaceUri == _nsOffice)
      .firstOrNull;
  if (body == null) {
    throw const FormatException('The ODT document has no text body.');
  }
  final blocks = <OfficeBlock>[];
  for (final element in body.descendants.whereType<XmlElement>()) {
    if (element.localName == 'p' && element.namespaceUri == _nsText) {
      final text = _odfParagraphText(element);
      if (text.trim().isEmpty) continue;
      final style =
          element.getAttribute('style-name', namespaceUri: _nsText) ?? '';
      final heading = RegExp(
        r'^Heading[_\s]?([1-6])$',
        caseSensitive: false,
      ).firstMatch(style);
      blocks.add(
        OfficeBlock.paragraph(
          text,
          headingLevel: heading == null ? 0 : int.parse(heading.group(1)!),
        ),
      );
    } else if (element.localName == 'h' && element.namespaceUri == _nsText) {
      final level =
          int.tryParse(
            element.getAttribute('outline-level', namespaceUri: _nsText) ?? '',
          ) ??
          1;
      final text = _odfParagraphText(element);
      if (text.trim().isEmpty) continue;
      blocks.add(OfficeBlock.paragraph(text, headingLevel: level));
    }
  }
  return OfficeDocument(
    format: OfficeFormat.odt,
    title: _metaTitle(package) ?? 'OpenDocument text',
    blocks: blocks,
    notes: [
      'Text and heading levels are carried. ODT frames, sections and embedded '
          'objects are not reproduced.',
    ],
  );
}

OfficeDocument _readOdfSheet(OfficePackage package) {
  final xml = package.textOf('content.xml');
  if (xml == null) {
    throw const FormatException('The ODS package has no content part.');
  }
  final root = _root(xml, part: 'content.xml');
  final blocks = <OfficeBlock>[];
  final names = <String>[];
  for (final table in root.descendants.whereType<XmlElement>().where(
    (e) => e.localName == 'table' && e.namespaceUri == _nsTable,
  )) {
    final name = table.getAttribute('name', namespaceUri: _nsTable) ?? 'Sheet';
    names.add(name);
    blocks.add(OfficeBlock.paragraph(name, bold: true));
    for (final row in table.childElements.where(
      (e) => e.localName == 'table-row' && e.namespaceUri == _nsTable,
    )) {
      final cells = <String>[];
      for (final cell in row.childElements.where(
        (e) => e.localName == 'table-cell' && e.namespaceUri == _nsTable,
      )) {
        final text = cell.descendants
            .whereType<XmlElement>()
            .where((e) => e.namespaceUri == _nsText)
            .map((e) => e.innerText)
            .join(' ')
            .trim();
        cells.add(text);
        final repeat =
            int.tryParse(
              cell.getAttribute(
                    'number-columns-repeated',
                    namespaceUri: _nsTable,
                  ) ??
                  '',
            ) ??
            1;
        // Cap repetition so a "3 million empty columns" marker cannot explode.
        for (var i = 1; i < repeat && i < 64; i++) {
          cells.add('');
        }
      }
      if (cells.every((c) => c.isEmpty)) continue;
      blocks.add(OfficeBlock.cells(cells));
    }
  }
  return OfficeDocument(
    format: OfficeFormat.ods,
    title: _metaTitle(package) ?? 'OpenDocument spreadsheet',
    blocks: blocks,
    sheetNames: names,
    notes: [
      'Cell text is carried per sheet. Formulas keep their displayed text; '
          'charts and formatting are not reproduced.',
    ],
  );
}

OfficeDocument _readOdfPresentation(OfficePackage package) {
  final xml = package.textOf('content.xml');
  if (xml == null) {
    throw const FormatException('The ODP package has no content part.');
  }
  final root = _root(xml, part: 'content.xml');
  final pages = root.descendants
      .whereType<XmlElement>()
      .where(
        (e) =>
            e.localName == 'page' &&
            e.namespaceUri ==
                'urn:oasis:names:tc:opendocument:xmlns:drawing:1.0',
      )
      .toList();
  final blocks = <OfficeBlock>[];
  var index = 0;
  for (final page in pages) {
    index++;
    final name = page.getAttribute(
      'name',
      namespaceUri: 'urn:oasis:names:tc:opendocument:xmlns:drawing:1.0',
    );
    blocks.add(
      OfficeBlock.paragraph(
        'Slide $index${name == null ? '' : ' — $name'}',
        headingLevel: 2,
      ),
    );
    for (final paragraph in page.descendants.whereType<XmlElement>().where(
      (e) => e.namespaceUri == _nsText && e.localName == 'p',
    )) {
      final text = _odfParagraphText(paragraph);
      if (text.trim().isEmpty) continue;
      blocks.add(OfficeBlock.paragraph(text));
    }
  }
  return OfficeDocument(
    format: OfficeFormat.odp,
    title: _metaTitle(package) ?? 'OpenDocument presentation',
    blocks: blocks,
    slideCount: pages.length,
    notes: [
      'Slide text is carried in drawing order. Graphics and animations are not '
          'reproduced.',
    ],
  );
}

String _odfParagraphText(XmlElement paragraph) {
  final buffer = StringBuffer();
  for (final node in paragraph.descendants) {
    if (node is XmlText) {
      buffer.write(node.value);
    } else if (node is XmlElement) {
      if (node.namespaceUri == _nsText && node.localName == 's') {
        final count =
            int.tryParse(node.getAttribute('c', namespaceUri: _nsText) ?? '') ??
            1;
        buffer.write(' ' * count.clamp(1, 200));
      } else if (node.namespaceUri == _nsText && node.localName == 'tab') {
        buffer.write('\t');
      } else if (node.namespaceUri == _nsText &&
          node.localName == 'line-break') {
        buffer.write('\n');
      }
    }
  }
  return buffer.toString();
}

String? _metaTitle(OfficePackage package) {
  final meta = package.textOf('meta.xml');
  if (meta == null) return null;
  try {
    final titles = XmlDocument.parse(meta)
        .findAllElements('title', namespaceUri: '*');
    if (titles.isEmpty) return null;
    final value = titles.first.innerText.trim();
    return value.isEmpty ? null : value;
  } on XmlException {
    return null;
  }
}

// ------------------------------------------------------------------- RTF

OfficeDocument _readRtf(Uint8List bytes) {
  final raw = String.fromCharCodes(bytes);
  final buffer = StringBuffer();
  var skipDepth = 0;
  var i = 0;
  while (i < raw.length) {
    final char = raw[i];
    if (char == '{') {
      // Skip font/colour/style tables and metadata groups verbatim.
      final ahead = raw.substring(i, (i + 40).clamp(0, raw.length));
      // Anchored at the brace itself: an inner {\fonttbl must not cause the
      // enclosing document group to be skipped.
      if (RegExp(r'^\{\\(fonttbl|colortbl|stylesheet|\*|info|pict)')
          .hasMatch(ahead)) {
        skipDepth = 1;
        i++;
        while (i < raw.length && skipDepth > 0) {
          if (raw[i] == '{') skipDepth++;
          if (raw[i] == '}') skipDepth--;
          i++;
        }
        continue;
      }
      i++;
      continue;
    }
    if (char == '}') {
      i++;
      continue;
    }
    if (char == '\\') {
      final rest = raw.substring(i);
      final control = RegExp(r"^\\([a-zA-Z]+)(-?\d+)?[ ]?|^\\([^a-zA-Z])")
          .firstMatch(rest);
      if (control == null) {
        i++;
        continue;
      }
      final word = control.group(1) ?? control.group(3) ?? '';
      if (word == 'par' || word == 'line' || word == 'sect') {
        buffer.write('\n');
      } else if (word == 'tab') {
        buffer.write('\t');
      } else if (word == 'u' && control.group(2) != null) {
        final code = int.tryParse(control.group(2)!);
        if (code != null) {
          var value = code < 0 ? code + 65536 : code;
          buffer.writeCharCode(value);
        }
      } else if (control.group(3) != null) {
        // Only a genuine escape such as \{ \} or \\ becomes literal text.
        // Single-letter control words (\f, \b, \i ...) carry formatting.
        buffer.write(word);
      }
      i += control.end;
      continue;
    }
    if (char == '\r' || char == '\n') {
      i++;
      continue;
    }
    buffer.write(char);
    i++;
  }
  final text = buffer
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return OfficeDocument(
    format: OfficeFormat.rtf,
    title: 'Rich Text document',
    blocks: [for (final line in text) OfficeBlock.paragraph(line)],
    notes: [
      'RTF is read as plain text with paragraph breaks; character formatting '
          'is not preserved.',
    ],
  );
}
