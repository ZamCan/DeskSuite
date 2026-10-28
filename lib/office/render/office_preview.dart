import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/brand.dart';
import 'office_layout.dart';

/// Draws parsed Office layout. The painting is deliberately dumb: every
/// decision was made by the parser, so what appears here is what the file
/// describes, not a guess made while painting.
class SlidePainter extends CustomPainter {
  SlidePainter({
    required this.slide,
    required this.images,
    required this.scale,
    required this.showNotes,
    this.fontFamily,
  });

  final OfficeSlide slide;

  /// Decoded pictures, keyed by the shape's index in `slide.shapes`.
  final Map<int, ui.Image> images;

  /// Device pixels per document point.
  final double scale;

  /// Whether to draw placeholders for objects the parser could not render.
  final bool showNotes;

  /// Used when the document does not name a face it can rely on.
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = Paint()..color = ZamCanBrand.documentPaper;
    canvas.drawRect(Offset.zero & size, paper);
    canvas.save();
    canvas.scale(scale);

    if (slide.background != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, slide.widthPt, slide.heightPt),
        Paint()..color = slide.background!.color,
      );
    }

    for (var i = 0; i < slide.shapes.length; i++) {
      final shape = slide.shapes[i];
      final bounds = shape.boundsPt;
      if (bounds == null) {
        if (showNotes) _note(canvas, shape.name, const Offset(8, 8));
        continue;
      }
      canvas.save();
      if (shape.rotationDegrees != 0) {
        final centre = bounds.center;
        canvas.translate(centre.dx, centre.dy);
        canvas.rotate(shape.rotationDegrees * 3.1415926535 / 180);
        canvas.translate(-centre.dx, -centre.dy);
      }
      _fillAndStroke(canvas, shape, bounds);
      switch (shape.kind) {
        case OfficeShapeKind.picture:
          final image = images[i];
          if (image != null) {
            paintImage(
              canvas: canvas,
              rect: bounds,
              image: image,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            );
          } else if (showNotes) {
            _note(canvas, 'Image unavailable', bounds.topLeft);
          }
        case OfficeShapeKind.table:
          _table(canvas, shape, bounds);
        default:
          if (shape.text != null) _text(canvas, shape.text!, bounds);
      }
      if (showNotes && shape.placeholderReason != null) {
        _note(canvas, shape.placeholderReason!, bounds.topLeft);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  void _fillAndStroke(Canvas canvas, OfficeShape shape, Rect bounds) {
    final path = switch (shape.kind) {
      OfficeShapeKind.ellipse => Path()..addOval(bounds),
      OfficeShapeKind.roundedRectangle =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            bounds,
            Radius.circular(
              shape.cornerRadiusPt.clamp(0, bounds.shortestSide / 2),
            ),
          ),
        ),
      OfficeShapeKind.triangle =>
        Path()
          ..moveTo(bounds.center.dx, bounds.top)
          ..lineTo(bounds.right, bounds.bottom)
          ..lineTo(bounds.left, bounds.bottom)
          ..close(),
      OfficeShapeKind.line =>
        Path()
          ..moveTo(bounds.left, bounds.center.dy)
          ..lineTo(bounds.right, bounds.center.dy),
      _ => Path()..addRect(bounds),
    };
    if (shape.fill != null &&
        shape.kind != OfficeShapeKind.picture &&
        shape.kind != OfficeShapeKind.table &&
        shape.kind != OfficeShapeKind.line) {
      canvas.drawPath(path, Paint()..color = shape.fill!.color);
    }
    if (shape.lineColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = shape.lineWidthPt
          ..color = shape.lineColor!.color,
      );
    }
  }

  void _text(Canvas canvas, OfficeTextBody body, Rect bounds) {
    final area = Rect.fromLTRB(
      bounds.left + body.insetLeftPt,
      bounds.top + body.insetTopPt,
      bounds.right - body.insetRightPt,
      bounds.bottom - body.insetBottomPt,
    );
    if (area.width <= 4 || area.height <= 4) return;

    final paragraphs = <_Laid>[];
    var total = 0.0;
    for (final paragraph in body.paragraphs) {
      final builder = StringBuffer();
      double? size;
      var bold = false;
      var italic = false;
      OfficeColor? color;
      String? fontFamily;
      for (final run in paragraph.runs) {
        builder.write(run.text);
        size ??= run.sizePt;
        bold = bold || run.bold;
        italic = italic || run.italic;
        color ??= run.color;
        fontFamily ??= run.fontFamily;
      }
      if (builder.isEmpty) continue;
      final fontSize = (size ?? 18).clamp(6.0, 400.0);
      final painter = TextPainter(
        text: TextSpan(
          text: paragraph.bullet
              ? '•  ${builder.toString()}'
              : builder.toString(),
          style: TextStyle(
            // The document names its own face; when that face is not on the
            // device the platform substitutes, which is what desktop readers
            // do too.
            // The run's own face wins; the document's theme font next. When
            // that face is not installed — Calibri is named by most decks and
            // ships nowhere — the bundled family takes over through the
            // fallback chain rather than rendering every glyph as a box.
            fontFamily: fontFamily,
            fontFamilyFallback: [if (this.fontFamily != null) this.fontFamily!],
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            color: color?.color ?? ZamCanBrand.documentInk,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: switch (paragraph.align) {
          OfficeAlign.center => TextAlign.center,
          OfficeAlign.right => TextAlign.right,
          OfficeAlign.justify => TextAlign.justify,
          OfficeAlign.left => TextAlign.left,
        },
        maxLines: body.wrap ? null : 1,
      )..layout(maxWidth: body.wrap ? area.width : double.infinity);
      final lineHeight = painter.height + paragraph.spaceBeforePt;
      paragraphs.add(
        _Laid(painter, lineHeight, paragraph.spaceAfterPt, paragraph.align),
      );
      total += lineHeight + paragraph.spaceAfterPt;
    }
    if (paragraphs.isEmpty) return;

    var y = switch (body.anchor) {
      OfficeVerticalAnchor.top => area.top,
      OfficeVerticalAnchor.middle => area.top + (area.height - total) / 2,
      OfficeVerticalAnchor.bottom => area.bottom - total,
    };
    for (final laid in paragraphs) {
      final dx = switch (laid.align) {
        OfficeAlign.center => area.left + (area.width - laid.painter.width) / 2,
        OfficeAlign.right => area.right - laid.painter.width,
        _ => area.left,
      };
      laid.painter.paint(canvas, Offset(dx, y));
      y += laid.height + laid.spaceAfter;
    }
  }

  void _table(Canvas canvas, OfficeShape shape, Rect bounds) {
    final table = shape.table;
    if (table == null) return;
    final widths = table.columnWidthsPt.isEmpty
        ? List<double>.filled(
            table.rows.isEmpty ? 1 : table.rows.first.cells.length,
            bounds.width /
                (table.rows.isEmpty ? 1 : table.rows.first.cells.length),
          )
        : table.columnWidthsPt;
    var rowTop = bounds.top;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75
      ..color = ZamCanBrand.sheetRule;
    for (final row in table.rows) {
      var columnLeft = bounds.left;
      var column = 0;
      for (final cell in row.cells) {
        final span = cell.columnSpan.clamp(1, widths.length);
        final width = widths
            .skip(column)
            .take(span)
            .fold<double>(0, (sum, w) => sum + w);
        final rect = Rect.fromLTWH(columnLeft, rowTop, width, row.heightPt);
        if (cell.fill != null) {
          canvas.drawRect(rect, Paint()..color = cell.fill!.color);
        }
        canvas.drawRect(rect, line);
        if (!cell.text.isEmpty) {
          _text(
            canvas,
            cell.text,
            Rect.fromLTWH(
              rect.left + 3,
              rect.top + 2,
              rect.width - 6,
              rect.height - 4,
            ),
          );
        }
        columnLeft += width;
        column += span;
      }
      rowTop += row.heightPt;
    }
  }

  void _note(Canvas canvas, String message, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: message,
        style: const TextStyle(fontSize: 7, color: ZamCanBrand.sheetNote),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200);
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant SlidePainter old) =>
      old.slide != slide ||
      old.scale != scale ||
      old.images.length != images.length;
}

class _Laid {
  const _Laid(this.painter, this.height, this.spaceAfter, this.align);
  final TextPainter painter;
  final double height;
  final double spaceAfter;
  final OfficeAlign align;
}

/// A zoomable, paged view of a real `.pptx`.
///
/// Slide size is the file's own; the widget fits it to the available width and
/// letterboxes. Pictures are decoded once and cached; a slide that fails to
/// decode simply shows the note instead of breaking the page.
class PptxViewer extends StatefulWidget {
  const PptxViewer({super.key, required this.deck, this.initialIndex = 0});

  final OfficeDeck deck;
  final int initialIndex;

  @override
  State<PptxViewer> createState() => _PptxViewerState();
}

class _PptxViewerState extends State<PptxViewer> {
  late int _index = widget.initialIndex.clamp(
    0,
    widget.deck.slides.isEmpty ? 0 : widget.deck.slides.length - 1,
  );
  final Map<String, ui.Image> _decoded = {};
  final Map<int, ui.Image> _slideImages = {};
  int _decodedFor = -1;

  @override
  void initState() {
    super.initState();
    _decodeCurrent();
  }

  @override
  void dispose() {
    for (final image in _decoded.values) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _decodeCurrent() async {
    if (_index == _decodedFor) return;
    final slide = widget.deck.slides[_index];
    final images = <int, ui.Image>{};
    for (var i = 0; i < slide.shapes.length; i++) {
      final picture = slide.shapes[i].picture;
      if (picture == null) continue;
      final cached = _decoded[_key(picture)];
      if (cached != null) {
        images[i] = cached;
        continue;
      }
      final decoded = await _decode(picture.bytes);
      if (decoded == null) continue;
      _decoded[_key(picture)] = decoded;
      images[i] = decoded;
    }
    if (!mounted) return;
    setState(() {
      _slideImages
        ..clear()
        ..addAll(images);
      _decodedFor = _index;
    });
  }

  String _key(OfficePicture picture) =>
      '${picture.bytes.length}:${identityHashCode(picture.bytes)}';

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      // A picture in a format the platform cannot decode (EMF, WMF) is left
      // out rather than failing the whole slide.
      return null;
    }
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.deck.slides.length - 1);
    if (next == _index) return;
    setState(() => _index = next);
    _decodeCurrent();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deck.slides.isEmpty) {
      return const Center(child: Text('This presentation has no slides.'));
    }
    final slide = widget.deck.slides[_index];
    final brand = ZamCanColors.of(context);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = [
                constraints.maxWidth / slide.widthPt,
                constraints.maxHeight / slide.heightPt,
              ].reduce((a, b) => a < b ? a : b);
              return Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: ZamCanBrand.documentPaper,
                    boxShadow: [
                      BoxShadow(
                        color: brand.ink.withValues(alpha: .12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  width: slide.widthPt * scale,
                  height: slide.heightPt * scale,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: Key('slide-${slide.index}'),
                      painter: SlidePainter(
                        slide: slide,
                        images: _slideImages,
                        scale: scale,
                        showNotes: true,
                        fontFamily: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.fontFamily,
                      ),
                      size: Size(slide.widthPt * scale, slide.heightPt * scale),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _Controls(
          label: '${slide.label} of ${widget.deck.slides.length}',
          onPrevious: _index == 0 ? null : () => _go(-1),
          onNext: _index >= widget.deck.slides.length - 1 ? null : () => _go(1),
          extra: slide.unsupported.isEmpty ? null : slide.unsupported.join(' '),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.label,
    this.onPrevious,
    this.onNext,
    this.extra,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String? extra;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        IconButton(
          key: const Key('slide-previous'),
          tooltip: 'Previous slide',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        IconButton(
          key: const Key('slide-next'),
          tooltip: 'Next slide',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        if (extra != null)
          Expanded(
            child: Text(
              extra!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    ),
  );
}

/// Draws a worksheet as a grid with row and column headers, formatted values,
/// merges, fills, and the sheet's own column widths and row heights.
class SheetPainter extends CustomPainter {
  SheetPainter({
    required this.sheet,
    required this.headerColor,
    required this.gridColor,
    required this.textColor,
    required this.headerTextColor,
    this.fontFamily,
  });

  final OfficeSheet sheet;
  final Color headerColor;
  final Color gridColor;
  final Color textColor;
  final Color headerTextColor;
  final String? fontFamily;

  /// Excel's column width unit is the width of the '0' glyph; 7 px at 11 pt is
  /// the value spreadsheet applications use, which keeps columns comparable.
  static const double charWidth = 7;
  static const double headerHeight = 18;
  static const double headerWidth = 34;

  double widthOf(int column) {
    final specified = column < sheet.columnWidthChars.length
        ? sheet.columnWidthChars[column]
        : null;
    return (specified ?? 8.43) * charWidth + 5;
  }

  double heightOf(int row) {
    final specified = row < sheet.rowHeightsPt.length
        ? sheet.rowHeightsPt[row]
        : null;
    return (specified ?? 15) + 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ZamCanBrand.documentPaper,
    );
    final rows = sheet.rowCount;
    final columns = sheet.columnCount;

    // Column headers.
    var x = headerWidth;
    final headerPaint = Paint()..color = headerColor;
    for (var c = 0; c < columns; c++) {
      final width = widthOf(c);
      canvas.drawRect(Rect.fromLTWH(x, 0, width, headerHeight), headerPaint);
      canvas.drawRect(
        Rect.fromLTWH(x, 0, width, headerHeight),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .5
          ..color = gridColor,
      );
      _label(
        canvas,
        _columnName(c),
        Offset(x + width / 2, headerHeight / 2),
        true,
      );
      x += width;
    }
    // Row headers and cells.
    var y = headerHeight;
    for (var r = 0; r < rows; r++) {
      final height = heightOf(r);
      canvas.drawRect(Rect.fromLTWH(0, y, headerWidth, height), headerPaint);
      canvas.drawRect(
        Rect.fromLTWH(0, y, headerWidth, height),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .5
          ..color = gridColor,
      );
      _label(canvas, '${r + 1}', Offset(headerWidth / 2, y + height / 2), true);

      var cellX = headerWidth;
      for (var c = 0; c < columns; c++) {
        var width = widthOf(c);
        final cell = sheet.rows.elementAtOrNull(r)?[c];
        if (cell != null && cell.columnSpan > 1) {
          for (var extra = 1; extra < cell.columnSpan; extra++) {
            width += widthOf(c + extra);
          }
        }
        final rect = Rect.fromLTWH(cellX, y, width, height);
        if (cell != null && !cell.mergedAway) {
          if (cell.fill != null) {
            canvas.drawRect(rect, Paint()..color = cell.fill!.color);
          }
          if (cell.display.isNotEmpty) {
            _cellText(canvas, cell, rect);
          }
        }
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .4
            ..color = gridColor,
        );
        if (cell != null && cell.columnSpan > 1) {
          c += cell.columnSpan - 1;
        } else {
          cellX += width;
          continue;
        }
        cellX += width;
      }
      y += height;
    }
  }

  void _cellText(Canvas canvas, OfficeCell cell, Rect rect) {
    final painter = TextPainter(
      text: TextSpan(
        text: cell.display,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: cell.sizePt.clamp(6, 72),
          fontWeight: cell.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: cell.italic ? FontStyle.italic : FontStyle.normal,
          color: cell.color?.color ?? textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: cell.wrap ? 3 : 1,
      ellipsis: '…',
      textAlign: switch (cell.align) {
        OfficeAlign.center => TextAlign.center,
        OfficeAlign.right => TextAlign.right,
        _ => TextAlign.left,
      },
    )..layout(maxWidth: rect.width - 6);
    final dy = cell.verticalCenter
        ? rect.top + (rect.height - painter.height) / 2
        : rect.top + 2;
    final dx = switch (cell.align) {
      OfficeAlign.center => rect.left + 3,
      OfficeAlign.right => rect.left + 3,
      _ => rect.left + 3,
    };
    painter.paint(canvas, Offset(dx, dy));
  }

  void _label(Canvas canvas, String text, Offset centre, bool header) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 9,
          color: header ? headerTextColor : textColor,
          fontWeight: header ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(centre.dx - painter.width / 2, centre.dy - painter.height / 2),
    );
  }

  static String _columnName(int index) {
    var name = '';
    var value = index + 1;
    while (value > 0) {
      final remainder = (value - 1) % 26;
      name = String.fromCharCode(65 + remainder) + name;
      value = (value - 1) ~/ 26;
    }
    return name;
  }

  @override
  bool shouldRepaint(covariant SheetPainter old) => old.sheet != sheet;
}

/// A scrollable view of a real `.xlsx`, with a tab per sheet.
class XlsxViewer extends StatefulWidget {
  const XlsxViewer({super.key, required this.book, this.initialSheet = 0});
  final OfficeWorkbook book;
  final int initialSheet;

  @override
  State<XlsxViewer> createState() => _XlsxViewerState();
}

class _XlsxViewerState extends State<XlsxViewer> {
  late int _sheet = widget.initialSheet.clamp(
    0,
    widget.book.sheets.isEmpty ? 0 : widget.book.sheets.length - 1,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.book.sheets.isEmpty) {
      return const Center(child: Text('This workbook has no sheets.'));
    }
    final brand = ZamCanColors.of(context);
    final sheet = widget.book.sheets[_sheet];
    final painter = SheetPainter(
      sheet: sheet,
      headerColor: brand.paper.withValues(alpha: .55),
      gridColor: ZamCanBrand.line,
      textColor: ZamCanBrand.ink,
      headerTextColor: brand.ink.withValues(alpha: .7),
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );
    var width = SheetPainter.headerWidth;
    for (var c = 0; c < sheet.columnCount; c++) {
      width += painter.widthOf(c);
    }
    var height = SheetPainter.headerHeight;
    for (var r = 0; r < sheet.rowCount; r++) {
      height += painter.heightOf(r);
    }
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: Key('sheet-${sheet.name}'),
                      painter: painter,
                      size: Size(width, height),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.book.sheets.length > 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < widget.book.sheets.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      key: Key('sheet-tab-${widget.book.sheets[i].name}'),
                      label: Text(widget.book.sheets[i].name),
                      selected: i == _sheet,
                      onSelected: (_) => setState(() => _sheet = i),
                    ),
                  ),
              ],
            ),
          ),
        if (sheet.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              sheet.notes.join(' '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// A full-screen host for a rendered preview, with the app bar a user expects
/// and a short, honest subtitle about what is being shown.
class OfficePreviewPage extends StatelessWidget {
  const OfficePreviewPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
    body: SafeArea(child: child),
  );
}
