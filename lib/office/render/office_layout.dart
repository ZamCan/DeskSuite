/// A layout model for Office files, in the document's own units.
///
/// The parsers in this directory read OOXML geometry — EMU offsets and
/// extents, column widths, row heights, font sizes in hundredths of a point,
/// theme colour references — and produce these structures. Rendering is then a
/// separate, dumb step, which means the hard part (understanding the file) is
/// testable without a screen, and the same model could drive a PDF export or a
/// headless renderer later.
///
/// Nothing here is a guess: a shape whose geometry is missing is reported as
/// `OfficeShape.unpositioned` rather than placed at the origin, so the UI can
/// say "this file does not describe where its shapes go" instead of showing a
/// pile of text in the corner.
library;

import 'dart:typed_data';
import 'dart:ui' show Color, Rect;

/// English Metric Unit: 914400 to the inch, 360000 to the centimetre,
/// 12700 to the point.
class Emu {
  const Emu(this.value);
  final double value;

  static const double perInch = 914400;
  static const double perPoint = 12700;

  factory Emu.fromPoints(double pt) => Emu(pt * perPoint);
  factory Emu.fromInches(double inches) => Emu(inches * perInch);

  double get points => value / perPoint;
  double get inches => value / perInch;

  Emu operator +(Emu other) => Emu(value + other.value);
  Emu operator -(Emu other) => Emu(value - other.value);

  @override
  String toString() => '${value.round()}emu';
}

/// A colour as written in the file, with the theme reference it resolved from.
///
/// `alpha` is kept separate because OOXML writes translucency as a percentage
/// modifier on the colour, not as an ARGB byte.
class OfficeColor {
  const OfficeColor(this.argb, {this.themeName, this.tint});

  /// 0xAARRGGBB.
  final int argb;
  final String? themeName;

  /// Lightening/darkening applied by the file (0 = untouched, 1 = white).
  final double? tint;

  Color get color => Color(argb);

  /// The colour a shape takes when the file names none and the theme
  /// cannot be resolved. Callers may substitute the document's default.
  static const OfficeColor black = OfficeColor(0xFF000000); // documentInk

  bool get isDark =>
      ((argb >> 16) & 0xFF) + ((argb >> 8) & 0xFF) + (argb & 0xFF) < 384;
}

/// One formatted run of text inside a paragraph.
class OfficeRun {
  const OfficeRun(
    this.text, {
    this.sizePt,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
    this.fontFamily,
  });

  final String text;
  final double? sizePt;
  final bool bold;
  final bool italic;
  final bool underline;
  final OfficeColor? color;
  final String? fontFamily;
}

enum OfficeAlign { left, center, right, justify }

/// A paragraph: runs plus the paragraph-level settings a viewer needs.
class OfficeParagraph {
  const OfficeParagraph({
    required this.runs,
    this.align = OfficeAlign.left,
    this.level = 0,
    this.bullet = false,
    this.spaceBeforePt = 0,
    this.spaceAfterPt = 0,
    this.lineSpacing,
  });

  final List<OfficeRun> runs;
  final OfficeAlign align;
  final int level;
  final bool bullet;
  final double spaceBeforePt;
  final double spaceAfterPt;

  /// Multiple of the font size, or null when the file does not say.
  final double? lineSpacing;

  bool get isEmpty => runs.every((run) => run.text.trim().isEmpty);
  String get plainText => runs.map((run) => run.text).join();
}

class OfficeTextBody {
  const OfficeTextBody({
    required this.paragraphs,
    this.anchor = OfficeVerticalAnchor.top,
    this.insetLeftPt = 7.2,
    this.insetRightPt = 7.2,
    this.insetTopPt = 3.6,
    this.insetBottomPt = 3.6,
    this.wrap = true,
  });

  final List<OfficeParagraph> paragraphs;
  final OfficeVerticalAnchor anchor;
  final double insetLeftPt;
  final double insetRightPt;
  final double insetTopPt;
  final double insetBottomPt;
  final bool wrap;

  bool get isEmpty => paragraphs.every((paragraph) => paragraph.isEmpty);

  /// Every paragraph's text, separated by newlines — what a text search or a
  /// copy action should see.
  String get plainText => paragraphs.map((p) => p.plainText).join('\n');
}

enum OfficeVerticalAnchor { top, middle, bottom }

/// Shape kinds this renderer can draw faithfully. Anything else is drawn as a
/// labelled placeholder, so an unsupported SmartArt or chart is visible as
/// itself rather than silently missing.
enum OfficeShapeKind {
  rectangle,
  roundedRectangle,
  ellipse,
  triangle,
  line,
  text,
  picture,
  table,
  placeholder,
}

class OfficeShape {
  const OfficeShape({
    required this.kind,
    required this.boundsPt,
    this.name = '',
    this.fill,
    this.lineColor,
    this.lineWidthPt = 1,
    this.cornerRadiusPt = 0,
    this.text,
    this.picture,
    this.table,
    this.rotationDegrees = 0,
    this.placeholderReason,
  });

  /// A shape the file does not position. Rendered as a note, never at (0,0).
  const OfficeShape.unpositioned({required this.name, required this.kind})
    : boundsPt = null,
      fill = null,
      lineColor = null,
      lineWidthPt = 1,
      cornerRadiusPt = 0,
      text = null,
      picture = null,
      table = null,
      rotationDegrees = 0,
      placeholderReason = 'The file does not position this object.';

  final OfficeShapeKind kind;

  /// Where the shape sits on the slide, in points. Null when unknown.
  final Rect? boundsPt;
  final String name;
  final OfficeColor? fill;
  final OfficeColor? lineColor;
  final double lineWidthPt;
  final double cornerRadiusPt;
  final OfficeTextBody? text;
  final OfficePicture? picture;
  final OfficeTable? table;
  final double rotationDegrees;
  final String? placeholderReason;

  bool get isPositioned => boundsPt != null;
}

class OfficePicture {
  const OfficePicture({
    required this.bytes,
    required this.mimeType,
    this.altText = '',
  });

  final Uint8List bytes;
  final String mimeType;
  final String altText;
}

class OfficeTable {
  const OfficeTable({required this.columnWidthsPt, required this.rows});

  final List<double> columnWidthsPt;
  final List<OfficeTableRow> rows;

  double get heightPt => rows.fold(0, (sum, row) => sum + row.heightPt);
}

class OfficeTableRow {
  const OfficeTableRow({required this.heightPt, required this.cells});
  final double heightPt;
  final List<OfficeTableCell> cells;
}

class OfficeTableCell {
  const OfficeTableCell({required this.text, this.fill, this.columnSpan = 1});

  final OfficeTextBody text;
  final OfficeColor? fill;
  final int columnSpan;
}

/// One slide, at the size the presentation declares.
class OfficeSlide {
  const OfficeSlide({
    required this.index,
    required this.widthPt,
    required this.heightPt,
    required this.shapes,
    this.background,
    this.unsupported = const [],
  });

  final int index;

  /// Declared slide size in points, from `p:sldSz`. Never assumed to be 4:3.
  final double widthPt;
  final double heightPt;
  final List<OfficeShape> shapes;
  final OfficeColor? background;

  /// Things the parser saw and could not draw, named for the UI.
  final List<String> unsupported;

  double get aspectRatio => widthPt / heightPt;

  String get label => 'Slide ${index + 1}';
}

class OfficeDeck {
  const OfficeDeck({
    required this.slides,
    required this.title,
    this.notes = const [],
  });
  final List<OfficeSlide> slides;
  final String title;
  final List<String> notes;
}

// ---------------------------------------------------------------------------
// Spreadsheets
// ---------------------------------------------------------------------------

enum OfficeCellKind { empty, number, text, boolean, date, error, formula }

/// One cell, already formatted for display by the number-format engine.
class OfficeCell {
  const OfficeCell({
    this.display = '',
    this.kind = OfficeCellKind.empty,
    this.number,
    this.formula,
    this.bold = false,
    this.italic = false,
    this.sizePt = 11,
    this.color,
    this.fill,
    this.align = OfficeAlign.left,
    this.verticalCenter = false,
    this.wrap = false,
    this.isDate = false,
    this.columnSpan = 1,
    this.mergedAway = false,
  });

  /// What a spreadsheet application would show, e.g. "4,500.00 TZS".
  final String display;
  final OfficeCellKind kind;
  final double? number;
  final String? formula;
  final bool bold;
  final bool italic;
  final double sizePt;
  final OfficeColor? color;
  final OfficeColor? fill;
  final OfficeAlign align;
  final bool verticalCenter;
  final bool wrap;
  final bool isDate;
  final int columnSpan;

  /// True for cells covered by a merge; they render as blank space.
  final bool mergedAway;

  bool get isEmpty => kind == OfficeCellKind.empty && display.isEmpty;
}

class OfficeSheet {
  const OfficeSheet({
    required this.name,
    required this.rows,
    required this.columnWidthChars,
    required this.rowHeightsPt,
    this.frozenRows = 0,
    this.frozenColumns = 0,
    this.notes = const [],
  });

  final String name;

  /// Cells by row index (0-based, as stored), each row a sparse map.
  final List<Map<int, OfficeCell>> rows;

  /// Widths in Excel character units, converted to points by the renderer.
  final List<double> columnWidthChars;
  final List<double> rowHeightsPt;
  final int frozenRows;
  final int frozenColumns;
  final List<String> notes;

  int get rowCount => rows.length;

  int get columnCount => rows.fold<int>(
    0,
    (widest, row) => row.keys.fold(
      widest,
      (inner, index) => index + 1 > inner ? index + 1 : inner,
    ),
  );
}

class OfficeWorkbook {
  const OfficeWorkbook({required this.sheets, required this.title});
  final List<OfficeSheet> sheets;
  final String title;
}
