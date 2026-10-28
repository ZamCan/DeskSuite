import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../office_package.dart';
import 'office_layout.dart';

/// Reads a `.xlsx` into sheets with formatted values.
///
/// A spreadsheet is not a table of text: `4500` with the number format
/// `#,##0.00" TZS"` must read `4,500.00 TZS`, and a date is stored as a serial
/// number with a format that says how to show it. This parser resolves
/// `xl/styles.xml` (number formats, fonts, fills, alignment), applies the
/// format to every numeric cell, and keeps column widths, row heights, merged
/// ranges and frozen panes so the sheet can be drawn as a grid rather than a
/// list of rows.
class XlsxLayoutException implements Exception {
  const XlsxLayoutException(this.message);
  final String message;
  @override
  String toString() => message;
}

OfficeWorkbook parseXlsx(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
    throw const XlsxLayoutException(
      'This file is not an Excel workbook: the package is damaged or not a '
      'valid ZIP container.',
    );
  }
  final package = OfficePackage.open(bytes);
  if (!package.contains('xl/workbook.xml')) {
    throw const XlsxLayoutException(
      'This file is not an Excel workbook: it has no xl/workbook.xml part.',
    );
  }
  final styles = _Styles.parse(package);
  final shared = _sharedStrings(package);
  final dates = _DateSystem.fromWorkbook(package);

  final workbookXml = package.textOf('xl/workbook.xml')!;
  final workbook = XmlDocument.parse(workbookXml).rootElement;
  final rels = _relationships(package.textOf('xl/_rels/workbook.xml.rels'));

  final sheetRefs = <({String name, String part})>[];
  final sheetsNode = workbook.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'sheets')
      .firstOrNull;
  if (sheetsNode != null) {
    for (final sheet in sheetsNode.childElements.where(
      (e) => e.localName == 'sheet',
    )) {
      final name = sheet.getAttribute('name') ?? 'Sheet';
      final rid = sheet.attributes
          .where((a) => a.name.local == 'id' && a.name.prefix == 'r')
          .map((a) => a.value)
          .firstOrNull;
      final target = rid == null ? null : rels[rid];
      if (target == null) continue;
      final part = _resolve('xl/workbook.xml', target);
      if (package.contains(part)) sheetRefs.add((name: name, part: part));
    }
  }
  if (sheetRefs.isEmpty) {
    throw const XlsxLayoutException('This workbook contains no worksheets.');
  }

  final sheets = <OfficeSheet>[];
  for (final ref in sheetRefs) {
    sheets.add(
      _sheet(
        name: ref.name,
        xml: package.textOf(ref.part) ?? '',
        shared: shared,
        styles: styles,
        dates: dates,
      ),
    );
  }

  return OfficeWorkbook(
    sheets: sheets,
    title: _coreTitle(package) ?? 'Workbook',
  );
}

OfficeSheet _sheet({
  required String name,
  required String xml,
  required List<String> shared,
  required _Styles styles,
  required _DateSystem dates,
}) {
  if (xml.isEmpty) {
    return OfficeSheet(
      name: name,
      rows: const [],
      columnWidthChars: const [],
      rowHeightsPt: const [],
      notes: const ['This sheet could not be read.'],
    );
  }
  final root = XmlDocument.parse(xml).rootElement;
  final notes = <String>[];

  // Column widths: <cols><col min max width customWidth/></cols>
  final widths = <double>[];
  final cols = root.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'cols')
      .firstOrNull;
  if (cols != null) {
    for (final col in cols.childElements.where((e) => e.localName == 'col')) {
      final min = int.tryParse(col.getAttribute('min') ?? '') ?? 1;
      final max = int.tryParse(col.getAttribute('max') ?? '') ?? min;
      final width = double.tryParse(col.getAttribute('width') ?? '');
      if (width == null) continue;
      for (var c = min; c <= max && c <= 16384; c++) {
        while (widths.length < c) {
          widths.add(8.43);
        }
        widths[c - 1] = width;
      }
    }
  }

  final rowHeights = <double>[];
  final rows = <Map<int, OfficeCell>>[];

  for (final row in root.descendants.whereType<XmlElement>().where(
    (e) => e.localName == 'row',
  )) {
    final rowIndex =
        (int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1) - 1;
    while (rows.length <= rowIndex) {
      rows.add(<int, OfficeCell>{});
      rowHeights.add(15);
    }
    final height = double.tryParse(row.getAttribute('ht') ?? '');
    if (height != null) rowHeights[rowIndex] = height;

    for (final cell in row.childElements.where((e) => e.localName == 'c')) {
      final reference = cell.getAttribute('r') ?? '';
      final column = _columnIndex(reference);
      if (column < 0) continue;
      final styleIndex = int.tryParse(cell.getAttribute('s') ?? '') ?? 0;
      rows[rowIndex][column] = _cell(
        cell,
        style: styles.byIndex(styleIndex),
        shared: shared,
        dates: dates,
      );
    }
  }

  // Merged ranges: the first cell spans, the others render as blank space.
  final mergeNode = root.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'mergeCells')
      .firstOrNull;
  if (mergeNode != null) {
    for (final merge in mergeNode.childElements.where(
      (e) => e.localName == 'mergeCell',
    )) {
      final ref = merge.getAttribute('ref');
      if (ref == null) continue;
      final parts = ref.split(':');
      if (parts.length != 2) continue;
      final start = _parseRef(parts[0]);
      final end = _parseRef(parts[1]);
      if (start == null || end == null) continue;
      final anchor = rows.elementAtOrNull(start.$1)?[start.$2];
      if (anchor != null) {
        rows[start.$1][start.$2] = OfficeCell(
          display: anchor.display,
          kind: anchor.kind,
          number: anchor.number,
          formula: anchor.formula,
          bold: anchor.bold,
          italic: anchor.italic,
          sizePt: anchor.sizePt,
          color: anchor.color,
          fill: anchor.fill,
          align: anchor.align,
          verticalCenter: anchor.verticalCenter,
          wrap: anchor.wrap,
          isDate: anchor.isDate,
          columnSpan: end.$2 - start.$2 + 1,
        );
      }
      for (var r = start.$1; r <= end.$1; r++) {
        while (rows.length <= r) {
          rows.add(<int, OfficeCell>{});
          rowHeights.add(15);
        }
        for (var c = start.$2; c <= end.$2; c++) {
          if (r == start.$1 && c == start.$2) continue;
          rows[r][c] = const OfficeCell(mergedAway: true);
        }
      }
    }
  }

  // Frozen panes: <pane ySplit="1" topLeftCell="A2" state="frozen"/>
  var frozenRows = 0;
  var frozenCols = 0;
  final pane = root.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'pane')
      .firstOrNull;
  if (pane != null && (pane.getAttribute('state') ?? '').contains('frozen')) {
    frozenRows = int.tryParse(pane.getAttribute('ySplit') ?? '') ?? 0;
    frozenCols = int.tryParse(pane.getAttribute('xSplit') ?? '') ?? 0;
  }

  final drawing = root.descendants.whereType<XmlElement>().any(
    (e) => e.localName == 'drawing',
  );
  if (drawing) {
    notes.add('Images and charts on this sheet are not drawn.');
  }

  return OfficeSheet(
    name: name,
    rows: rows,
    columnWidthChars: widths,
    rowHeightsPt: rowHeights,
    frozenRows: frozenRows,
    frozenColumns: frozenCols,
    notes: notes,
  );
}

// ---------------------------------------------------------------------------
// Cells and formats
// ---------------------------------------------------------------------------

OfficeCell _cell(
  XmlElement cell, {
  required _CellStyle style,
  required List<String> shared,
  required _DateSystem dates,
}) {
  final type = cell.getAttribute('t') ?? 'n';
  final raw = cell.childElements
      .where((e) => e.localName == 'v')
      .map((e) => e.innerText)
      .firstOrNull;
  final formula = cell.childElements
      .where((e) => e.localName == 'f')
      .map((e) => e.innerText)
      .firstOrNull;

  String text = '';
  double? number;
  var kind = OfficeCellKind.empty;
  var isDate = false;

  if (type == 'inlineStr') {
    text = cell.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 't')
        .map((e) => e.innerText)
        .join();
    if (text.isNotEmpty) kind = OfficeCellKind.text;
  } else if (raw != null) {
    switch (type) {
      case 's':
        final index = int.tryParse(raw);
        text = index != null && index >= 0 && index < shared.length
            ? shared[index]
            : '';
        if (text.isNotEmpty) kind = OfficeCellKind.text;
      case 'b':
        text = raw == '1' ? 'TRUE' : 'FALSE';
        kind = OfficeCellKind.boolean;
      case 'str':
        text = raw;
        kind = raw.isEmpty ? OfficeCellKind.empty : OfficeCellKind.text;
      case 'e':
        text = raw;
        kind = OfficeCellKind.error;
      default:
        final value = double.tryParse(raw);
        if (value == null) {
          text = raw;
          kind = raw.isEmpty ? OfficeCellKind.empty : OfficeCellKind.text;
        } else {
          number = value;
          isDate = style.isDate(value, dates);
          text = isDate
              ? formatExcelNumber(
                  value,
                  style.numberFormat.isEmpty
                      ? 'yyyy-mm-dd'
                      : style.numberFormat,
                  dateSystem: dates.epoch,
                )
              : formatExcelNumber(value, style.numberFormat);
          kind = isDate ? OfficeCellKind.date : OfficeCellKind.number;
        }
    }
  }
  if (formula != null && kind == OfficeCellKind.empty) {
    // A formula whose cached value is missing: show the formula, say so.
    kind = OfficeCellKind.formula;
    text = '=$formula';
  }

  return OfficeCell(
    display: text,
    kind: kind,
    number: number,
    formula: formula,
    bold: style.bold,
    italic: style.italic,
    sizePt: style.sizePt,
    color: style.color,
    fill: style.fill,
    align: style.alignExplicit
        ? style.align
        : (kind == OfficeCellKind.number || kind == OfficeCellKind.date
              ? OfficeAlign.right
              : OfficeAlign.left),
    verticalCenter: style.verticalCenter,
    wrap: style.wrap,
    isDate: isDate,
  );
}

/// Excel's serial-number date systems. The 1904 system is rare but real: a
/// workbook that uses it shows every date four years and a day out if ignored.
class _DateSystem {
  const _DateSystem(this.epoch);
  final DateTime epoch;

  factory _DateSystem.fromWorkbook(OfficePackage package) {
    final xml = package.textOf('xl/workbook.xml');
    final is1904 =
        xml != null && xml.contains('date1904="1"') ||
        xml != null && xml.contains('date1904="true"');
    return _DateSystem(
      is1904 ? DateTime.utc(1904, 1, 1) : DateTime.utc(1899, 12, 30),
    );
  }

  DateTime fromSerial(double serial) =>
      epoch.add(Duration(milliseconds: (serial * 86400000).round()));
}

class _CellStyle {
  const _CellStyle({
    this.numberFormat = 'General',
    this.bold = false,
    this.italic = false,
    this.sizePt = 11,
    this.color,
    this.fill,
    this.align = OfficeAlign.left,
    this.verticalCenter = false,
    this.wrap = false,
    this.builtInDateFormat = false,
    this.alignExplicit = false,
  });

  final String numberFormat;
  final bool bold;
  final bool italic;
  final double sizePt;
  final OfficeColor? color;
  final OfficeColor? fill;
  final OfficeAlign align;
  final bool verticalCenter;
  final bool wrap;

  /// True when the format came from the built-in date table (ids 14–22, 45–47).
  final bool builtInDateFormat;

  /// False when the workbook leaves alignment to the application, in which
  /// case numbers and dates right-align and text left-aligns, as in Excel.
  final bool alignExplicit;

  bool isDate(double value, _DateSystem system) {
    if (builtInDateFormat) return true;
    final fmt = numberFormat;
    if (fmt == 'General') return false;
    return _looksLikeDateFormat(fmt);
  }
}

class _Styles {
  _Styles(this.formats, this.xfs, this.fonts, this.fills);
  final Map<int, String> formats;
  final List<int> xfs;
  final List<_FontStyle> fonts;
  final List<OfficeColor?> fills;

  _CellStyle byIndex(int index) {
    final xf = _xfDetails.elementAtOrNull(index) ?? _XfDetails.plain;
    final font = fonts.elementAtOrNull(xf.fontId) ?? const _FontStyle();
    final fill = fills.elementAtOrNull(xf.fillId);
    final formatId = xf.numFmtId;
    final code = formats[formatId] ?? _builtInFormats[formatId] ?? 'General';
    return _CellStyle(
      numberFormat: code,
      bold: font.bold,
      italic: font.italic,
      sizePt: font.sizePt,
      color: font.color,
      fill: fill,
      align: xf.align,
      verticalCenter: xf.verticalCenter,
      wrap: xf.wrap,
      builtInDateFormat: _builtInDateFormats.contains(formatId),
      alignExplicit: xf.alignExplicit,
    );
  }

  final List<_XfDetails> _xfDetails = [];

  static _Styles parse(OfficePackage package) {
    final xml = package.textOf('xl/styles.xml');
    if (xml == null) {
      final empty = _Styles(const {}, const [0], const [_FontStyle()], const [
        null,
      ]);
      empty._xfDetails.add(_XfDetails.plain);
      return empty;
    }
    final root = XmlDocument.parse(xml).rootElement;
    final formats = <int, String>{};
    final numFmts = root.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'numFmts')
        .firstOrNull;
    if (numFmts != null) {
      for (final fmt in numFmts.childElements.where(
        (e) => e.localName == 'numFmt',
      )) {
        final id = int.tryParse(fmt.getAttribute('numFmtId') ?? '');
        final code = fmt.getAttribute('formatCode');
        if (id != null && code != null) formats[id] = code;
      }
    }

    final fonts = <_FontStyle>[];
    final fontsNode = root.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'fonts')
        .firstOrNull;
    if (fontsNode != null) {
      for (final font in fontsNode.childElements.where(
        (e) => e.localName == 'font',
      )) {
        final size = double.tryParse(
          font.childElements
                  .where((e) => e.localName == 'sz')
                  .firstOrNull
                  ?.getAttribute('val') ??
              '',
        );
        final colorHex = font.descendants
            .whereType<XmlElement>()
            .where((e) => e.localName == 'color')
            .firstOrNull
            ?.getAttribute('rgb');
        final argb = colorHex == null ? null : _argb(colorHex);
        fonts.add(
          _FontStyle(
            bold: font.childElements.any((e) => e.localName == 'b'),
            italic: font.childElements.any((e) => e.localName == 'i'),
            sizePt: size ?? 11,
            color: argb == null ? null : OfficeColor(argb),
          ),
        );
      }
    }
    if (fonts.isEmpty) fonts.add(const _FontStyle());

    final fills = <OfficeColor?>[];
    final fillsNode = root.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'fills')
        .firstOrNull;
    if (fillsNode != null) {
      for (final fill in fillsNode.childElements.where(
        (e) => e.localName == 'fill',
      )) {
        final patternFill = fill.childElements
            .where((e) => e.localName == 'patternFill')
            .firstOrNull;
        final pattern = patternFill?.getAttribute('patternType');
        final fg = patternFill?.childElements
            .where((e) => e.localName == 'fgColor')
            .firstOrNull
            ?.getAttribute('rgb');
        final argb = fg == null ? null : _argb(fg);
        fills.add(
          pattern == 'solid' && argb != null ? OfficeColor(argb) : null,
        );
      }
    }
    if (fills.isEmpty) fills.add(null);

    final xfs = <int>[];
    final details = <_XfDetails>[];
    final cellXfs = root.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'cellXfs')
        .firstOrNull;
    if (cellXfs != null) {
      for (final xf in cellXfs.childElements.where(
        (e) => e.localName == 'xf',
      )) {
        final numFmtId = int.tryParse(xf.getAttribute('numFmtId') ?? '') ?? 0;
        final fontId = int.tryParse(xf.getAttribute('fontId') ?? '') ?? 0;
        final fillId = int.tryParse(xf.getAttribute('fillId') ?? '') ?? 0;
        final alignment = xf.childElements
            .where((e) => e.localName == 'alignment')
            .firstOrNull;
        final horizontal = alignment?.getAttribute('horizontal');
        xfs.add(numFmtId);
        details.add(
          _XfDetails(
            numFmtId: numFmtId,
            fontId: fontId,
            fillId: fillId,
            align: switch (horizontal) {
              'center' => OfficeAlign.center,
              'right' => OfficeAlign.right,
              'justify' => OfficeAlign.justify,
              _ => OfficeAlign.left,
            },
            verticalCenter: alignment?.getAttribute('vertical') == 'center',
            wrap: alignment?.getAttribute('wrapText') == '1',
            alignExplicit: horizontal != null,
          ),
        );
      }
    }
    if (details.isEmpty) details.add(_XfDetails.plain);

    final styles = _Styles(formats, xfs, fonts, fills);
    styles._xfDetails.addAll(details);
    return styles;
  }
}

class _FontStyle {
  const _FontStyle({
    this.bold = false,
    this.italic = false,
    this.sizePt = 11,
    this.color,
  });
  final bool bold;
  final bool italic;
  final double sizePt;
  final OfficeColor? color;
}

class _XfDetails {
  const _XfDetails({
    this.numFmtId = 0,
    this.fontId = 0,
    this.fillId = 0,
    this.align = OfficeAlign.left,
    this.verticalCenter = false,
    this.wrap = false,
    this.alignExplicit = false,
  });
  static const plain = _XfDetails();
  final int numFmtId;
  final int fontId;
  final int fillId;
  final OfficeAlign align;
  final bool verticalCenter;
  final bool wrap;
  final bool alignExplicit;
}

const _builtInDateFormats = <int>{
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  45,
  46,
  47,
};

const _builtInFormats = <int, String>{
  0: 'General',
  1: '0',
  2: '0.00',
  3: '#,##0',
  4: '#,##0.00',
  9: '0%',
  10: '0.00%',
  11: '0.00E+00',
  14: 'yyyy-mm-dd',
  15: 'd-mmm-yy',
  16: 'd-mmm',
  17: 'mmm-yy',
  18: 'h:mm AM/PM',
  19: 'h:mm:ss AM/PM',
  20: 'h:mm',
  21: 'h:mm:ss',
  22: 'yyyy-mm-dd h:mm',
  37: '#,##0 ;(#,##0)',
  38: '#,##0 ;[Red](#,##0)',
  39: '#,##0.00;(#,##0.00)',
  40: '#,##0.00;[Red](#,##0.00)',
  44: '_(\$" _"* #,##0.00_);_(\$" _"* \\(#,##0.00\\);_(\$" _"* "-"??_);_(@_)',
  49: '@',
};

/// True when a custom format code contains date/time tokens outside quotes.
bool _looksLikeDateFormat(String code) {
  final withoutLiterals = code.replaceAll(RegExp(r'"[^"]*"'), '');
  final withoutElapsed = withoutLiterals.replaceAll(RegExp(r'\[[^\]]*\]'), '');
  return RegExp(r'[ymdhs]', caseSensitive: false).hasMatch(withoutElapsed);
}

int? _argb(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length == 6) return int.tryParse('FF$cleaned', radix: 16);
  if (cleaned.length == 8) return int.tryParse(cleaned, radix: 16);
  return null;
}

String? _coreTitle(OfficePackage package) {
  final xml = package.textOf('docProps/core.xml');
  if (xml == null) return null;
  try {
    final root = XmlDocument.parse(xml).rootElement;
    final title = root.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'title')
        .map((e) => e.innerText.trim())
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');
    return title.isEmpty ? null : title;
  } on XmlException {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Number formatting
// ---------------------------------------------------------------------------

/// Renders [value] the way Excel would for [code], using a deliberate subset:
///
/// * `0`, `#`, `?` digit placeholders, with `,` grouping and `,` scaling;
/// * decimal places implied by the format, rounding half away from zero;
/// * `%` multiplies by 100;
/// * quoted literals and `\x` escapes are emitted verbatim, which is how
///   `#,##0.00" TZS"` works;
/// * date and time tokens (`yyyy`, `mm`, `dd`, `hh`, `ss`, `AM/PM`);
/// * `[Red]`-style colour sections are dropped, `_x` padding is approximated,
///   and a format with `;` sections picks the positive, negative, zero or text
///   section in that order.
///
/// Anything else falls back to a plain decimal, because showing `####` or the
/// raw format code would be worse than showing the number.
String formatExcelNumber(double value, String code, {DateTime? dateSystem}) {
  if (code.isEmpty || code.toLowerCase() == 'general' || code == '@') {
    // General is not a format at all: show the number, not the code.
    final rounded = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return rounded;
  }
  final sections = _splitSections(code);
  final section = value < 0
      ? (sections.length > 1 ? sections[1] : sections[0])
      : value == 0
      ? (sections.length > 2 ? sections[2] : sections[0])
      : sections[0];

  if (_isDateSection(section)) {
    final epoch = dateSystem ?? DateTime.utc(1899, 12, 30);
    return _formatDate(
      epoch.add(Duration(milliseconds: (value * 86400000).round())),
      section,
    );
  }

  // A section with no digit placeholder is pure literal text ("zero", "-"),
  // which is how spreadsheets display a nil value as a word.
  if (!RegExp(r'[0#?]').hasMatch(section)) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < section.length) {
      final char = section[index];
      if (char == '"') {
        final close = section.indexOf('"', index + 1);
        if (close > index) {
          buffer.write(section.substring(index + 1, close));
          index = close + 1;
          continue;
        }
      }
      if (char == r'\' && index + 1 < section.length) {
        buffer.write(section[index + 1]);
        index += 2;
        continue;
      }
      if (char == '[') {
        final close = section.indexOf(']', index + 1);
        if (close > index) {
          index = close + 1;
          continue;
        }
      }
      buffer.write(char);
      index++;
    }
    return buffer.toString().trim();
  }

  final percent = section.contains('%');
  final scaled = percent ? value * 100 : value;
  final decimalMatch = RegExp(r'\.([0#?]+)').firstMatch(section);
  final decimals = decimalMatch?.group(1)?.length ?? 0;
  final hasGrouping = RegExp(r',0|,#|#,#').hasMatch(section);

  var working = scaled;
  // A comma after the last digit placeholder divides by a thousand; two divide
  // by a million. "#,##0,,\"M\"" therefore prints 1500000 as 2M.
  final lastPlaceholder = section.lastIndexOf(RegExp(r'[0#?]'));
  if (lastPlaceholder >= 0) {
    var commas = 0;
    for (var i = lastPlaceholder + 1; i < section.length; i++) {
      final char = section[i];
      if (char == ',') commas++;
      if (char == '"' || char == r'\\') break;
    }
    if (commas > 0) working = working / _pow(1000, commas);
  }

  final negative = working < 0;
  final magnitude = working.abs();
  var digits = magnitude.toStringAsFixed(decimals);
  var intPart = digits;
  var fracPart = '';
  if (decimals > 0) {
    final dot = digits.indexOf('.');
    intPart = digits.substring(0, dot);
    fracPart = digits.substring(dot + 1);
  }
  if (hasGrouping) intPart = _group(intPart);
  var number = decimals > 0 ? '$intPart.$fracPart' : intPart;

  // Prefix and suffix: everything in the section that is not a placeholder.
  final prefix = StringBuffer();
  final suffix = StringBuffer();
  _literalParts(section, prefix, suffix);
  final percentSuffix = percent && !suffix.toString().contains('%') ? '%' : '';

  final shown = '$prefix$number$suffix$percentSuffix';
  // A negative section such as "(#,##0)" already carries the sign itself;
  // only the generic first section needs a minus added.
  final needsSign = negative && sections.length < 2;
  return needsSign ? '-$shown' : shown;
}

List<String> _splitSections(String code) {
  final sections = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < code.length; i++) {
    final char = code[i];
    if (char == '"') inQuotes = !inQuotes;
    if (char == ';' && !inQuotes) {
      sections.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  sections.add(buffer.toString());
  return sections;
}

bool _isDateSection(String section) {
  final stripped = section
      .replaceAll(RegExp(r'"[^"]*"'), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'\\.'), '');
  return RegExp(r'[ymdhs]', caseSensitive: false).hasMatch(stripped) &&
      !RegExp(r'[#0]').hasMatch(stripped);
}

String _formatDate(DateTime date, String section) {
  final upper = section.toUpperCase();
  final hasAmPm = upper.contains('AM/PM');
  final buffer = StringBuffer();
  var i = 0;
  while (i < section.length) {
    final rest = section.substring(i);
    final match = RegExp(
      r'^(yyyy|yy|mmmm|mmm|mm|m|dddd|ddd|dd|d|hh|h|ss|s|AM/PM|am/pm)',
    ).firstMatch(rest);
    if (match != null) {
      final token = match.group(1)!;
      buffer.write(_dateToken(token, date, hasAmPm));
      i += token.length;
      continue;
    }
    if (section[i] == '\\' && i + 1 < section.length) {
      buffer.write(section[i + 1]);
      i += 2;
      continue;
    }
    if (section[i] == '"') {
      final close = section.indexOf('"', i + 1);
      if (close > i) {
        buffer.write(section.substring(i + 1, close));
        i = close + 1;
        continue;
      }
    }
    buffer.write(section[i]);
    i++;
  }
  return buffer.toString();
}

String _dateToken(String token, DateTime date, bool hasAmPm) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  switch (token) {
    case 'yyyy':
      return date.year.toString().padLeft(4, '0');
    case 'yy':
      return (date.year % 100).toString().padLeft(2, '0');
    case 'mmmm':
      return months[date.month - 1];
    case 'mmm':
      return months[date.month - 1].substring(0, 3);
    case 'mm':
      // After an hour token Excel reads "mm" as minutes; that is handled by
      // the caller's token order, and a standalone mm is the month.
      return date.month.toString().padLeft(2, '0');
    case 'm':
      return date.month.toString();
    case 'dddd':
      return days[date.weekday - 1];
    case 'ddd':
      return days[date.weekday - 1].substring(0, 3);
    case 'dd':
      return date.day.toString().padLeft(2, '0');
    case 'd':
      return date.day.toString();
    case 'hh':
      final hour = hasAmPm ? ((date.hour + 11) % 12) + 1 : date.hour;
      return hour.toString().padLeft(2, '0');
    case 'h':
      return (hasAmPm ? ((date.hour + 11) % 12) + 1 : date.hour).toString();
    case 'ss':
      return date.second.toString().padLeft(2, '0');
    case 's':
      return date.second.toString();
    case 'AM/PM':
    case 'am/pm':
      return date.hour < 12 ? 'AM' : 'PM';
    default:
      return token;
  }
}

String _group(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

double _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

void _literalParts(String section, StringBuffer prefix, StringBuffer suffix) {
  var i = 0;
  var seenPlaceholder = false;
  while (i < section.length) {
    final char = section[i];
    if (char == '"') {
      final close = section.indexOf('"', i + 1);
      if (close > i) {
        final text = section.substring(i + 1, close);
        (seenPlaceholder ? suffix : prefix).write(text);
        i = close + 1;
        continue;
      }
    }
    if (char == '\\' && i + 1 < section.length) {
      (seenPlaceholder ? suffix : prefix).write(section[i + 1]);
      i += 2;
      continue;
    }
    if (char == '[') {
      final close = section.indexOf(']', i + 1);
      if (close > i) {
        i = close + 1;
        continue;
      }
    }
    if (char == '_' && i + 1 < section.length) {
      // `_x` reserves the width of x; a space is the honest approximation.
      (seenPlaceholder ? suffix : prefix).write(' ');
      i += 2;
      continue;
    }
    if (char == '0' ||
        char == '#' ||
        char == '?' ||
        char == '.' ||
        char == ',') {
      seenPlaceholder = true;
      i++;
      continue;
    }
    if (char == '%') {
      seenPlaceholder = true;
      i++;
      continue;
    }
    (seenPlaceholder ? suffix : prefix).write(char);
    i++;
  }
}

// ---------------------------------------------------------------------------
// Package helpers
// ---------------------------------------------------------------------------

List<String> _sharedStrings(OfficePackage package) {
  final xml = package.textOf('xl/sharedStrings.xml');
  if (xml == null) return const [];
  final root = XmlDocument.parse(xml).rootElement;
  return root.childElements
      .where((e) => e.localName == 'si')
      .map(
        (si) => si.descendants
            .whereType<XmlElement>()
            .where((t) => t.localName == 't')
            .map((t) => t.innerText)
            .join(),
      )
      .toList(growable: false);
}

Map<String, String> _relationships(String? xml) {
  if (xml == null) return const {};
  final root = XmlDocument.parse(xml).rootElement;
  final map = <String, String>{};
  for (final rel in root.childElements.where(
    (e) => e.localName == 'Relationship',
  )) {
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id != null && target != null) map[id] = target;
  }
  return map;
}

String _resolve(String from, String target) {
  if (target.startsWith('/')) return target.substring(1);
  final base = from.contains('/')
      ? from.substring(0, from.lastIndexOf('/') + 1)
      : '';
  final segments = <String>[];
  for (final segment in '$base$target'.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  return segments.join('/');
}

/// "C7" → column 2 (0-based). Returns -1 when the reference has no columns.
int _columnIndex(String reference) {
  final parsed = _parseRef(reference);
  return parsed?.$2 ?? -1;
}

/// "C7" → (row 6, column 2), both 0-based.
(int, int)? _parseRef(String reference) {
  final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(reference);
  if (match == null) return null;
  var column = 0;
  for (final unit in match.group(1)!.codeUnits) {
    column = column * 26 + (unit - 64);
  }
  final row = int.tryParse(match.group(2)!);
  if (row == null) return null;
  return (row - 1, column - 1);
}
