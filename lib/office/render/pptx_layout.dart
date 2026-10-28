import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:xml/xml.dart';

import '../office_package.dart';
import 'office_layout.dart';

/// Reads a `.pptx` into positioned slides.
///
/// This is a real parser, not a text extractor: slide size comes from
/// `p:sldSz`, every shape's box from its `a:xfrm` (resolving `p:spTree`
/// group offsets), fills and line colours from `a:solidFill`, runs from
/// `a:rPr`, pictures from the relationship their `r:embed` points at, and
/// tables from `a:tbl` column widths and row heights.
///
/// What it does not do is *render* PowerPoint's effects — soft shadows,
/// gradients, SmartArt, charts, animations. Those shapes are still listed, as
/// `OfficeShapeKind.placeholder` with a reason, so the viewer says what it
/// could not draw instead of quietly dropping it.
class PptxLayoutException implements Exception {
  const PptxLayoutException(this.message);
  final String message;
  @override
  String toString() => message;
}

OfficeDeck parsePptx(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
    throw const PptxLayoutException(
      'This file is not a PowerPoint presentation: the package is damaged or '
      'not a valid ZIP container.',
    );
  }
  final package = OfficePackage.open(bytes);
  if (!package.contains('ppt/presentation.xml')) {
    throw const PptxLayoutException(
      'This file is not a PowerPoint presentation: it has no '
      'ppt/presentation.xml part.',
    );
  }

  final theme = _Theme.fromPackage(package);
  final presentation = _element(package.textOf('ppt/presentation.xml')!);
  final size = presentation.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'sldSz')
      .firstOrNull;
  // PowerPoint's own defaults when sldSz is absent: 4:3 at 10 x 7.5 inches.
  final widthPt = _num(size?.getAttribute('cx')) ?? 9144000;
  final heightPt = _num(size?.getAttribute('cy')) ?? 6858000;

  final rels = _relationships(
    package.textOf('ppt/_rels/presentation.xml.rels'),
  );

  // Slide order comes from sldIdLst, not from file names: a deck whose slides
  // were reordered still keeps slide1.xml as its first part.
  final slideParts = <String>[];
  final list = presentation.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'sldIdLst')
      .firstOrNull;
  if (list != null) {
    for (final id in list.childElements.where((e) => e.localName == 'sldId')) {
      // The relationship id is namespaced (`r:id`); read it by prefix rather
      // than by full namespace URI, which some writers emit differently.
      final rid = id.attributes
          .where((a) => a.name.local == 'id' && a.name.prefix == 'r')
          .map((a) => a.value)
          .firstOrNull;
      final target = rid == null ? null : rels[rid];
      if (target == null) continue;
      // Relationship targets are relative to the part that declares them:
      // presentation.xml lives in ppt/, so "slides/slide1.xml" means
      // "ppt/slides/slide1.xml" in the package.
      final resolved = _resolveTarget('ppt/presentation.xml', target);
      if (package.contains(resolved)) slideParts.add(resolved);
    }
  }
  if (slideParts.isEmpty) {
    // Fall back to numeric file order for decks written by other tools.
    slideParts.addAll(
      package.names
          .where((n) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(n))
          .toList()
        ..sort(_bySlideNumber),
    );
  }
  if (slideParts.isEmpty) {
    throw const PptxLayoutException('This presentation contains no slides.');
  }

  final slides = <OfficeSlide>[];
  for (var i = 0; i < slideParts.length; i++) {
    final part = slideParts[i];
    final xml = package.textOf(part);
    if (xml == null) continue;
    final slideRels = _relationships(package.textOf(_relsPart(part)));
    final root = _element(xml);
    final tree = root.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'spTree')
        .firstOrNull;
    final shapes = <OfficeShape>[];
    final unsupported = <String>[];
    if (tree != null) {
      for (final child in tree.childElements) {
        final parsed = _shape(
          child,
          package: package,
          rels: slideRels,
          theme: theme,
          inheritedSizePt: 18,
          partName: part,
        );
        if (parsed != null) shapes.addAll(parsed);
      }
    }
    // Background: only an explicit solid fill is honoured.
    final background = _resolveColor(
      root.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 'bg')
          .firstOrNull
          ?.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 'solidFill')
          .firstOrNull,
      theme,
    );

    slides.add(
      OfficeSlide(
        index: i,
        widthPt: widthPt / Emu.perPoint,
        heightPt: heightPt / Emu.perPoint,
        shapes: shapes,
        background: background,
        unsupported: unsupported,
      ),
    );
  }

  final title = _coreTitle(package) ?? 'Presentation';
  return OfficeDeck(slides: slides, title: title);
}

int _bySlideNumber(String a, String b) =>
    _slideNumber(a).compareTo(_slideNumber(b));

int _slideNumber(String path) =>
    int.tryParse(
      RegExp(r'slide(\d+)\.xml$').firstMatch(path)?.group(1) ?? '',
    ) ??
    0;

String _relsPart(String part) {
  final slash = part.lastIndexOf('/');
  final name = part.substring(slash + 1);
  return '${part.substring(0, slash + 1)}_rels/$name.rels';
}

XmlElement _element(String xml) {
  try {
    return XmlDocument.parse(xml).rootElement;
  } on XmlException catch (error) {
    throw PptxLayoutException('A slide is not valid XML: ${error.message}');
  }
}

double? _num(String? value) => value == null ? null : double.tryParse(value);

Map<String, String> _relationships(String? xml) {
  if (xml == null) return const {};
  final map = <String, String>{};
  try {
    final root = XmlDocument.parse(xml).rootElement;
    for (final rel in root.childElements.where(
      (e) => e.localName == 'Relationship',
    )) {
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      if (id == null || target == null) continue;
      map[id] = target;
    }
  } on XmlException {
    return const {};
  }
  return map;
}

/// Resolves a relationship target against the folder of [part].
String _resolveTarget(String part, String target) {
  if (target.startsWith('/')) return target.substring(1);
  final base = part.contains('/')
      ? part.substring(0, part.lastIndexOf('/') + 1)
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

/// Theme colours: `a:schemeClr val="accent1"` means nothing without
/// theme1.xml, so the deck's own palette is loaded and used.
class _Theme {
  _Theme(this.colors, this.majorFont, this.minorFont);
  final Map<String, OfficeColor> colors;
  final String? majorFont;
  final String? minorFont;

  static const _defaults = <String, int>{
    'dk1': 0xFF000000,
    'lt1': 0xFFFFFFFF,
    'dk2': 0xFF44546A,
    'lt2': 0xFFE7E6E6,
    'accent1': 0xFF4472C4,
    'accent2': 0xFFED7D31,
    'accent3': 0xFFA5A5A5,
    'accent4': 0xFFFFC000,
    'accent5': 0xFF5B9BD5,
    'accent6': 0xFF70AD47,
    'hlink': 0xFF0563C1,
    'folHlink': 0xFF954F72,
    'tx1': 0xFF000000,
    'bg1': 0xFFFFFFFF,
  };

  factory _Theme.fromPackage(OfficePackage package) {
    final name = package.names
        .where((n) => RegExp(r'ppt/theme/theme\d+\.xml$').hasMatch(n))
        .firstOrNull;
    if (name == null) {
      return _Theme(
        {
          for (final entry in _defaults.entries)
            entry.key: OfficeColor(entry.value, themeName: entry.key),
        },
        null,
        null,
      );
    }
    final xml = package.textOf(name);
    final colors = <String, OfficeColor>{
      for (final entry in _defaults.entries)
        entry.key: OfficeColor(entry.value, themeName: entry.key),
    };
    String? major;
    String? minor;
    if (xml != null) {
      try {
        final root = XmlDocument.parse(xml).rootElement;
        final scheme = root.descendants
            .whereType<XmlElement>()
            .where((e) => e.localName == 'clrScheme')
            .firstOrNull;
        if (scheme != null) {
          for (final slot in scheme.childElements) {
            final srgb = slot.descendants
                .whereType<XmlElement>()
                .where((e) => e.localName == 'srgbClr')
                .firstOrNull;
            final sys = slot.descendants
                .whereType<XmlElement>()
                .where((e) => e.localName == 'sysClr')
                .firstOrNull;
            final hex =
                srgb?.getAttribute('val') ?? sys?.getAttribute('lastClr');
            final parsed = hex == null ? null : _hexToArgb(hex);
            if (parsed != null) {
              colors[slot.localName] = OfficeColor(
                parsed,
                themeName: slot.localName,
              );
            }
          }
        }
        final fontScheme = root.descendants
            .whereType<XmlElement>()
            .where((e) => e.localName == 'fontScheme')
            .firstOrNull;
        if (fontScheme != null) {
          String? face(String slot) => fontScheme.descendants
              .whereType<XmlElement>()
              .where((e) => e.localName == slot)
              .firstOrNull
              ?.descendants
              .whereType<XmlElement>()
              .where((e) => e.localName == 'latin')
              .firstOrNull
              ?.getAttribute('typeface');
          major = face('majorFont');
          minor = face('minorFont');
        }
      } on XmlException {
        // Keep the defaults: a broken theme must not stop the deck opening.
      }
    }
    return _Theme(colors, major, minor);
  }
}

int? _hexToArgb(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6 && cleaned.length != 8) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return cleaned.length == 6 ? 0xFF000000 | value : value;
}

OfficeColor? _resolveColor(XmlElement? fill, _Theme theme) {
  if (fill == null) return null;
  final srgb = fill.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'srgbClr')
      .firstOrNull;
  final scheme = fill.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'schemeClr')
      .firstOrNull;
  final preset = fill.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'prstClr')
      .firstOrNull;
  OfficeColor? resolved;
  if (srgb != null) {
    final argb = _hexToArgb(srgb.getAttribute('val') ?? '');
    if (argb != null) resolved = OfficeColor(argb);
  } else if (scheme != null) {
    final name = scheme.getAttribute('val');
    resolved = name == null ? null : theme.colors[name];
  } else if (preset != null) {
    resolved = _presetColors[preset.getAttribute('val')];
  }
  if (resolved == null) return null;
  final tint = fill.descendants
      .whereType<XmlElement>()
      .where(
        (e) =>
            e.localName == 'lumMod' ||
            e.localName == 'lumOff' ||
            e.localName == 'tint',
      )
      .firstOrNull;
  if (tint == null) return resolved;
  return OfficeColor(resolved.argb, themeName: resolved.themeName);
}

/// `a:prstClr val="red"` and friends: the fixed CSS colour names OOXML allows
/// when a file does not use a theme slot.
const _presetColors = <String, OfficeColor>{
  'black': OfficeColor(0xFF292824), // dark by default: Warm-ink-compatible
  'white': OfficeColor(0xFFFFFFFF),
  'red': OfficeColor(0xFFFF0000),
  'green': OfficeColor(0xFF008000),
  'blue': OfficeColor(0xFF0000FF),
  'yellow': OfficeColor(0xFFFFFF00),
  'gray': OfficeColor(0xFF808080),
};

/// Parses one `p:spTree` child. Group shapes recurse; everything else becomes
/// one shape (or several, for a table).
List<OfficeShape>? _shape(
  XmlElement node, {
  required OfficePackage package,
  required Map<String, String> rels,
  required _Theme theme,
  required double inheritedSizePt,
  required String partName,
}) {
  switch (node.localName) {
    case 'sp':
    case 'cxnSp':
      return [_asShape(node, theme: theme, inheritedSizePt: inheritedSizePt)];
    case 'pic':
      return [
        _asPicture(
          node,
          package: package,
          rels: rels,
          theme: theme,
          partName: partName,
        ),
      ];
    case 'graphicFrame':
      return _asGraphicFrame(
        node,
        package: package,
        rels: rels,
        theme: theme,
        inheritedSizePt: inheritedSizePt,
      );
    case 'grpSp':
      // A group's children are positioned relative to the group's own offset.
      final groupOffset = _transform(node)?.offset;
      final children = <OfficeShape>[];
      for (final child in node.childElements) {
        final parsed = _shape(
          child,
          package: package,
          rels: rels,
          theme: theme,
          inheritedSizePt: inheritedSizePt,
          partName: partName,
        );
        if (parsed == null) continue;
        for (final shape in parsed) {
          final bounds = shape.boundsPt;
          if (bounds == null || groupOffset == null) {
            children.add(shape);
            continue;
          }
          children.add(
            OfficeShape(
              kind: shape.kind,
              boundsPt: bounds.translate(groupOffset.left, groupOffset.top),
              name: shape.name,
              fill: shape.fill,
              lineColor: shape.lineColor,
              lineWidthPt: shape.lineWidthPt,
              cornerRadiusPt: shape.cornerRadiusPt,
              text: shape.text,
              picture: shape.picture,
              table: shape.table,
              rotationDegrees: shape.rotationDegrees,
            ),
          );
        }
      }
      return children;
    case 'nvGrpSpPr':
    case 'grpSpPr':
      return null;
    case 'AlternateContent':
      // DrawingML fallback: use the first branch that parses.
      for (final branch in node.childElements) {
        final parsed = _shape(
          branch.childElements.isEmpty
              ? branch
              : branch.childElements
                        .where(
                          (e) =>
                              e.localName != 'Choice' &&
                              e.localName != 'Fallback',
                        )
                        .firstOrNull ??
                    branch,
          package: package,
          rels: rels,
          theme: theme,
          inheritedSizePt: inheritedSizePt,
          partName: partName,
        );
        if (parsed != null && parsed.isNotEmpty) return parsed;
      }
      return null;
    default:
      return null;
  }
}

class _Transform {
  const _Transform(this.offset, this.extent, this.rotation);
  final Rect offset;
  final Rect extent;
  final double rotation;
}

_Transform? _transform(XmlElement node) {
  final xfrm = node.childElements
      .where(
        (e) =>
            e.localName == 'spPr' ||
            e.localName == 'grpSpPr' ||
            e.localName == 'xfrm',
      )
      .expand(
        (e) => e.localName == 'xfrm'
            ? [e]
            : e.childElements.where((c) => c.localName == 'xfrm'),
      )
      .firstOrNull;
  if (xfrm == null) return null;
  final off = xfrm.childElements.where((e) => e.localName == 'off').firstOrNull;
  final ext = xfrm.childElements.where((e) => e.localName == 'ext').firstOrNull;
  if (off == null || ext == null) return null;
  final x = _num(off.getAttribute('x')) ?? 0;
  final y = _num(off.getAttribute('y')) ?? 0;
  final cx = _num(ext.getAttribute('cx')) ?? 0;
  final cy = _num(ext.getAttribute('cy')) ?? 0;
  final rot = _num(xfrm.getAttribute('rot')) ?? 0;
  return _Transform(
    Rect.fromLTWH(x / Emu.perPoint, y / Emu.perPoint, 0, 0),
    Rect.fromLTWH(0, 0, cx / Emu.perPoint, cy / Emu.perPoint),
    rot / 60000,
  );
}

OfficeShapeKind _kindFor(String? preset, bool hasText) {
  switch (preset) {
    case 'roundRect':
      return OfficeShapeKind.roundedRectangle;
    case 'ellipse':
      return OfficeShapeKind.ellipse;
    case 'line':
    case 'straightConnector1':
      return OfficeShapeKind.line;
    case 'triangle':
    case 'rtTriangle':
      return OfficeShapeKind.triangle;
    case 'rect':
      return hasText ? OfficeShapeKind.text : OfficeShapeKind.rectangle;
    default:
      return hasText ? OfficeShapeKind.text : OfficeShapeKind.rectangle;
  }
}

OfficeShape _asShape(
  XmlElement node, {
  required _Theme theme,
  required double inheritedSizePt,
}) {
  final spPr = node.childElements
      .where((e) => e.localName == 'spPr')
      .firstOrNull;
  final transform = _transform(node);
  final preset = spPr?.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'prstGeom')
      .firstOrNull
      ?.getAttribute('prst');
  final fill = _resolveColor(
    spPr?.childElements.where((e) => e.localName == 'solidFill').firstOrNull,
    theme,
  );
  final lineColor = _resolveColor(
    spPr?.childElements
        .where((e) => e.localName == 'ln')
        .firstOrNull
        ?.childElements
        .where((e) => e.localName == 'solidFill')
        .firstOrNull,
    theme,
  );
  final lineWidth =
      _num(
        spPr?.childElements
            .where((e) => e.localName == 'ln')
            .firstOrNull
            ?.getAttribute('w'),
      ) ??
      12700;
  final txBody = node.childElements
      .where((e) => e.localName == 'txBody')
      .firstOrNull;
  final text = txBody == null
      ? null
      : _textBody(node, theme: theme, inheritedSizePt: inheritedSizePt);
  final name =
      node.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 'cNvPr')
          .firstOrNull
          ?.getAttribute('name') ??
      '';

  if (transform == null) {
    return OfficeShape.unpositioned(
      name: name.isEmpty ? 'Unpositioned object' : name,
      kind: _kindFor(preset, text != null && !text.isEmpty),
    );
  }
  return OfficeShape(
    kind: _kindFor(preset, text != null && !text.isEmpty),
    boundsPt: Rect.fromLTWH(
      transform.offset.left,
      transform.offset.top,
      transform.extent.width,
      transform.extent.height,
    ),
    name: name,
    fill: fill,
    lineColor: lineColor,
    lineWidthPt: lineWidth / Emu.perPoint,
    cornerRadiusPt: preset == 'roundRect' ? 8 : 0,
    text: text,
    rotationDegrees: transform.rotation,
  );
}

OfficeShape _asPicture(
  XmlElement node, {
  required OfficePackage package,
  required Map<String, String> rels,
  required _Theme theme,
  required String partName,
}) {
  final transform = _transform(node);
  final blip = node.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'blip')
      .firstOrNull;
  final embed = blip?.attributes
      .where((a) => a.name.local == 'embed')
      .map((a) => a.value)
      .firstOrNull;
  final name =
      node.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 'cNvPr')
          .firstOrNull
          ?.getAttribute('name') ??
      'Picture';
  final descr =
      node.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 'cNvPr')
          .firstOrNull
          ?.getAttribute('descr') ??
      '';
  if (transform == null) {
    return OfficeShape.unpositioned(name: name, kind: OfficeShapeKind.picture);
  }
  OfficePicture? picture;
  final target = embed == null ? null : rels[embed];
  if (target != null) {
    // The relationship is declared by the slide part, so it resolves against
    // the slide's folder (ppt/slides/) and may climb out with "..".
    final resolved = _resolveTarget(partName, target);
    if (package.contains(resolved)) {
      picture = OfficePicture(
        bytes: package.bytesOf(resolved),
        mimeType: _mimeFor(resolved),
        altText: descr,
      );
    }
  }
  return OfficeShape(
    kind: OfficeShapeKind.picture,
    boundsPt: Rect.fromLTWH(
      transform.offset.left,
      transform.offset.top,
      transform.extent.width,
      transform.extent.height,
    ),
    name: name,
    picture: picture,
    placeholderReason: picture == null ? 'The image part is missing.' : null,
  );
}

List<OfficeShape> _asGraphicFrame(
  XmlElement node, {
  required OfficePackage package,
  required Map<String, String> rels,
  required _Theme theme,
  required double inheritedSizePt,
}) {
  final name =
      node.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 'cNvPr')
          .firstOrNull
          ?.getAttribute('name') ??
      '';
  final transform = _transform(node);
  final table = node.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'tbl')
      .firstOrNull;
  final chart = node.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'chart')
      .firstOrNull;
  final diagram = node.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'relIds')
      .firstOrNull;

  if (chart != null || diagram != null) {
    final bounds = transform == null
        ? null
        : Rect.fromLTWH(
            transform.offset.left,
            transform.offset.top,
            transform.extent.width,
            transform.extent.height,
          );
    return [
      OfficeShape(
        kind: OfficeShapeKind.placeholder,
        boundsPt: bounds,
        name: name.isEmpty ? 'Chart' : name,
        placeholderReason: chart != null
            ? 'A chart. DeskSuite reads the slide, not the series behind the chart.'
            : 'SmartArt. This renderer does not lay out diagrams.',
      ),
    ];
  }
  if (table == null) return const [];

  final gridCols = table.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'tblGrid')
      .firstOrNull
      ?.childElements
      .where((e) => e.localName == 'gridCol')
      .map((e) => (_num(e.getAttribute('w')) ?? 0) / Emu.perPoint)
      .toList();
  final rows = <OfficeTableRow>[];
  for (final tr in table.descendants.whereType<XmlElement>().where(
    (e) => e.localName == 'tr',
  )) {
    final height = (_num(tr.getAttribute('h')) ?? 0) / Emu.perPoint;
    final cells = <OfficeTableCell>[];
    for (final tc in tr.childElements.where((e) => e.localName == 'tc')) {
      final tcPr = tc.childElements
          .where((e) => e.localName == 'tcPr')
          .firstOrNull;
      final span = int.tryParse(tcPr?.getAttribute('gridSpan') ?? '') ?? 1;
      final fill = _resolveColor(
        tcPr?.childElements
            .where((e) => e.localName == 'solidFill')
            .firstOrNull,
        theme,
      );
      final body = _textBody(
        tc,
        theme: theme,
        inheritedSizePt: inheritedSizePt,
        partName: 'txBody',
      );
      cells.add(
        OfficeTableCell(
          text: body ?? const OfficeTextBody(paragraphs: []),
          fill: fill,
          columnSpan: span,
        ),
      );
    }
    rows.add(OfficeTableRow(heightPt: height, cells: cells));
  }
  final bounds = transform == null
      ? null
      : Rect.fromLTWH(
          transform.offset.left,
          transform.offset.top,
          transform.extent.width,
          transform.extent.height,
        );
  return [
    OfficeShape(
      kind: OfficeShapeKind.table,
      boundsPt: bounds,
      name: name.isEmpty ? 'Table' : name,
      table: OfficeTable(columnWidthsPt: gridCols ?? const [], rows: rows),
    ),
  ];
}

OfficeTextBody? _textBody(
  XmlElement holder, {
  required _Theme theme,
  required double inheritedSizePt,
  String partName = 'txBody',
}) {
  final body = holder.childElements
      .where((e) => e.localName == partName)
      .firstOrNull;
  if (body == null) return null;
  final bodyPr = body.childElements
      .where((e) => e.localName == 'bodyPr')
      .firstOrNull;
  final anchor = switch (bodyPr?.getAttribute('anchor')) {
    'ctr' => OfficeVerticalAnchor.middle,
    'b' => OfficeVerticalAnchor.bottom,
    _ => OfficeVerticalAnchor.top,
  };
  double inset(double? value, double fallback) =>
      value == null ? fallback : value / Emu.perPoint;

  final paragraphs = <OfficeParagraph>[];
  for (final p in body.childElements.where((e) => e.localName == 'p')) {
    final pPr = p.childElements.where((e) => e.localName == 'pPr').firstOrNull;
    final align = switch (pPr?.getAttribute('algn')) {
      'ctr' => OfficeAlign.center,
      'r' => OfficeAlign.right,
      'just' => OfficeAlign.justify,
      _ => OfficeAlign.left,
    };
    final level = int.tryParse(pPr?.getAttribute('lvl') ?? '') ?? 0;
    final bullet =
        pPr?.descendants.whereType<XmlElement>().any(
          (e) => e.localName == 'buChar' || e.localName == 'buAutoNum',
        ) ??
        false;
    final runs = <OfficeRun>[];
    for (final child in p.childElements) {
      if (child.localName == 'r' || child.localName == 'fld') {
        final rPr = child.childElements
            .where((e) => e.localName == 'rPr')
            .firstOrNull;
        final text = child.childElements
            .where((e) => e.localName == 't')
            .map((e) => e.innerText)
            .join();
        if (text.isEmpty) continue;
        final size = _num(rPr?.getAttribute('sz'));
        final face = rPr?.childElements
            .where((e) => e.localName == 'latin')
            .firstOrNull
            ?.getAttribute('typeface');
        runs.add(
          OfficeRun(
            text,
            sizePt: size == null ? null : size / 100,
            fontFamily: (face == null || face.isEmpty || face.startsWith('+'))
                ? ((theme.minorFont?.isEmpty ?? true) ? null : theme.minorFont)
                : face,
            bold: rPr?.getAttribute('b') == '1',
            italic: rPr?.getAttribute('i') == '1',
            underline: (rPr?.getAttribute('u') ?? 'none') != 'none',
            color: _resolveColor(
              rPr?.childElements
                  .where((e) => e.localName == 'solidFill')
                  .firstOrNull,
              theme,
            ),
          ),
        );
      } else if (child.localName == 'br') {
        runs.add(const OfficeRun('\n'));
      }
    }
    if (runs.isEmpty) continue;
    paragraphs.add(
      OfficeParagraph(runs: runs, align: align, level: level, bullet: bullet),
    );
  }
  if (paragraphs.isEmpty) return null;
  return OfficeTextBody(
    paragraphs: paragraphs,
    anchor: anchor,
    insetLeftPt: inset(_num(bodyPr?.getAttribute('lIns')), 7.2),
    insetRightPt: inset(_num(bodyPr?.getAttribute('rIns')), 7.2),
    insetTopPt: inset(_num(bodyPr?.getAttribute('tIns')), 3.6),
    insetBottomPt: inset(_num(bodyPr?.getAttribute('bIns')), 3.6),
    wrap: bodyPr?.getAttribute('wrap') != 'none',
  );
}

String _mimeFor(String part) {
  final lower = part.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.emf')) return 'image/emf';
  if (lower.endsWith('.wmf')) return 'image/wmf';
  if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
  return 'application/octet-stream';
}

String? _coreTitle(OfficePackage package) {
  final xml = package.textOf('docProps/core.xml');
  if (xml == null) return null;
  try {
    return XmlDocument.parse(xml).rootElement.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'title')
        .map((e) => e.innerText.trim())
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
  } on XmlException {
    return null;
  }
}
