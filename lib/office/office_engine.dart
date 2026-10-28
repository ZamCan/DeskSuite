import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'office_format.dart';
import 'office_pdf.dart';
import 'office_reader.dart';
import 'office_writer.dart';

/// How faithful an output is expected to be. Shown to the user before they run
/// a conversion, so nobody is promised a layout the engine cannot deliver.
enum Fidelity {
  /// Text, headings, tables and emphasis survive; page layout does not.
  content('Content preserved, layout not reproduced'),

  /// Text only.
  textOnly('Text only'),

  /// Produced by an external engine that renders the original layout.
  rendered('Rendered by an external office engine');

  const Fidelity(this.description);
  final String description;
}

/// One supported conversion. A route is only listed when an engine that can
/// actually run it for this platform is present.
class OfficeRoute {
  const OfficeRoute({
    required this.from,
    required this.to,
    required this.engine,
    required this.fidelity,
    required this.detail,
    this.notes = const [],
    this.requiresExternalEngine = false,
  });

  final OfficeFormat from;
  final OfficeFormat to;
  final String engine;
  final Fidelity fidelity;
  final String detail;
  final List<String> notes;
  final bool requiresExternalEngine;

  String get id => '${from.label}→${to.label}';
}

class OfficeConversion {
  const OfficeConversion({
    required this.bytes,
    required this.format,
    required this.fileName,
    required this.route,
    this.notes = const [],
  });

  final Uint8List bytes;
  final OfficeFormat format;
  final String fileName;
  final OfficeRoute route;
  final List<String> notes;

  int get sizeBytes => bytes.length;
}

/// Capability seam for an external office conversion engine.
///
/// No executable discovery, Termux integration or LibreOffice adapter is
/// configured in this build. LibreOffice can be embedded on Android by other
/// applications; that is not an implemented DeskSuite conversion route.
/// The experimental read-only preview is separate and does not convert files.
abstract class ExternalOfficeEngine {
  String get label;
  Future<bool> isAvailable();
  Future<Uint8List> convert({
    required Uint8List bytes,
    required String inputExtension,
    required OfficeFormat to,
  });
}

/// Default engine: no external office suite is configured.
class NoExternalOfficeEngine implements ExternalOfficeEngine {
  const NoExternalOfficeEngine();

  @override
  String get label => 'No external office engine configured';

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Uint8List> convert({
    required Uint8List bytes,
    required String inputExtension,
    required OfficeFormat to,
  }) async {
    throw UnsupportedError(
      'No external office conversion engine is configured in this build.',
    );
  }
}

/// Central conversion registry for office formats.
class OfficeEngine {
  OfficeEngine({this.external = const NoExternalOfficeEngine()});

  final ExternalOfficeEngine external;

  /// Routes available without any external software.
  static const List<OfficeRoute> builtInRoutes = [
    _officeToPdf,
    _spreadsheetToPdf,
    _officeToText,
    _spreadsheetToCsv,
    _textToPdf,
    _htmlToPdf,
    _officeToOdt,
    _spreadsheetToOds,
  ];

  static const OfficeRoute _officeToPdf = OfficeRoute(
    from: OfficeFormat.docx,
    to: OfficeFormat.pdf,
    engine: 'DeskSuite reader + PDF writer',
    fidelity: Fidelity.content,
    detail:
        'Reads the document text, headings, emphasis and tables and writes a '
        'selectable-text PDF.',
    notes: [
      'Page breaks follow the content, not the original file.',
      'Images, columns, text boxes and exact fonts are not reproduced.',
    ],
  );

  static const OfficeRoute _spreadsheetToPdf = OfficeRoute(
    from: OfficeFormat.xlsx,
    to: OfficeFormat.pdf,
    engine: 'DeskSuite reader + PDF writer',
    fidelity: Fidelity.content,
    detail: 'Renders sheet values as printable tables with selectable text.',
    notes: [
      'Cell values are printed as text; number formats and colours are not kept.',
    ],
  );

  static const OfficeRoute _officeToText = OfficeRoute(
    from: OfficeFormat.docx,
    to: OfficeFormat.txt,
    engine: 'DeskSuite reader',
    fidelity: Fidelity.textOnly,
    detail: 'Extracts paragraph text in reading order as UTF-8.',
  );

  static const OfficeRoute _spreadsheetToCsv = OfficeRoute(
    from: OfficeFormat.xlsx,
    to: OfficeFormat.txt,
    engine: 'DeskSuite reader',
    fidelity: Fidelity.textOnly,
    detail: 'Writes sheet rows as comma-separated values with quoting.',
    notes: ['Multiple sheets are separated by a "# Sheet: name" line.'],
  );

  static const OfficeRoute _textToPdf = OfficeRoute(
    from: OfficeFormat.txt,
    to: OfficeFormat.pdf,
    engine: 'DeskSuite PDF writer',
    fidelity: Fidelity.textOnly,
    detail: 'Wraps plain text into printable A4 pages.',
  );

  static const OfficeRoute _htmlToPdf = OfficeRoute(
    from: OfficeFormat.html,
    to: OfficeFormat.pdf,
    engine: 'DeskSuite HTML text reader + PDF writer',
    fidelity: Fidelity.textOnly,
    detail: 'Strips markup, keeps block structure and writes printable pages.',
    notes: ['Styling, images and scripts are not rendered.'],
  );

  static const OfficeRoute _officeToOdt = OfficeRoute(
    from: OfficeFormat.docx,
    to: OfficeFormat.odt,
    engine: 'DeskSuite reader + OpenDocument writer',
    fidelity: Fidelity.content,
    detail:
        'Writes a real OpenDocument text package with headings and '
        'paragraphs that opens in LibreOffice.',
    notes: ['Exact fonts, images and layout are not carried over.'],
  );

  static const OfficeRoute _spreadsheetToOds = OfficeRoute(
    from: OfficeFormat.xlsx,
    to: OfficeFormat.ods,
    engine: 'DeskSuite reader + OpenDocument writer',
    fidelity: Fidelity.content,
    detail: 'Writes a real OpenDocument spreadsheet with one table per sheet.',
    notes: ['Cell formatting, charts and formulas are written as values.'],
  );

  /// Every route this build can execute right now, for the given input format.
  ///
  /// The rules are explicit and one route wins per (input, output) pair, so the
  /// UI can never offer two engines for the same job or a job one of them would
  /// silently corrupt.
  Future<List<OfficeRoute>> routesFor(OfficeFormat from) async {
    final routes = <OfficeRoute>[];
    final text = from.isReadable || from == OfficeFormat.txt;
    if (!text && from != OfficeFormat.html) {
      // Legacy binary and PDF need an external engine.
      if (await external.isAvailable()) {
        routes.addAll(_externalRoutes(from));
      }
      return routes;
    }
    routes.add(_pdfRouteFor(from));
    if (from == OfficeFormat.txt) return routes;
    if (_isSpreadsheet(from)) {
      routes
        ..add(_spreadsheetToCsv)
        ..add(_spreadsheetToOdsFor(from));
    } else {
      routes
        ..add(_officeToText)
        ..add(_officeToOdtFor(from));
    }
    if (await external.isAvailable()) {
      routes.addAll(_externalRoutes(from));
    }
    return routes;
  }

  static bool _isSpreadsheet(OfficeFormat format) =>
      format == OfficeFormat.xlsx || format == OfficeFormat.ods;

  List<OfficeRoute> _externalRoutes(OfficeFormat from) => [
    OfficeRoute(
      from: from,
      to: OfficeFormat.pdf,
      engine: external.label,
      fidelity: Fidelity.rendered,
      detail: 'Renders the original layout through the external office engine.',
      requiresExternalEngine: true,
      notes: const [
        'Layout fidelity depends on the installed office engine and the '
            'fonts available on this device.',
      ],
    ),
  ];

  static OfficeRoute _pdfRouteFor(OfficeFormat from) {
    if (from == OfficeFormat.html) return _htmlToPdf;
    if (from == OfficeFormat.txt) return _textToPdf;
    return _isSpreadsheet(from) ? _spreadsheetToPdf : _officeToPdf;
  }

  static OfficeRoute _officeToOdtFor(OfficeFormat from) =>
      from == OfficeFormat.docx ? _officeToOdt : _officeToOdtFromOffice(from);

  static OfficeRoute _spreadsheetToOdsFor(OfficeFormat from) =>
      from == OfficeFormat.xlsx
      ? _spreadsheetToOds
      : _spreadsheetToOdsFromOffice(from);

  static OfficeRoute _officeToOdtFromOffice(OfficeFormat from) => OfficeRoute(
    from: from,
    to: OfficeFormat.odt,
    engine: 'DeskSuite reader + OpenDocument writer',
    fidelity: Fidelity.content,
    detail: 'Writes an OpenDocument text package from the readable content.',
    notes: const [
      'Layout, fonts and images of the original are not carried over.',
    ],
  );

  static OfficeRoute _spreadsheetToOdsFromOffice(OfficeFormat from) =>
      OfficeRoute(
        from: from,
        to: OfficeFormat.ods,
        engine: 'DeskSuite reader + OpenDocument writer',
        fidelity: Fidelity.content,
        detail: 'Writes an OpenDocument spreadsheet from the sheet values.',
        notes: const [
          'Formats and formulas of the original are not carried over.',
        ],
      );

  /// Executes [route] for [bytes]. The source is never modified; the caller
  /// receives new output bytes and decides where to write them.
  Future<OfficeConversion> convert({
    required Uint8List bytes,
    required OfficeRoute route,
    String? sourceName,
  }) async {
    final base = _baseName(sourceName);
    if (route.requiresExternalEngine) {
      final output = await external.convert(
        bytes: bytes,
        inputExtension: route.from.label.toLowerCase(),
        to: route.to,
      );
      _assertPdf(output);
      return OfficeConversion(
        bytes: output,
        format: route.to,
        fileName: '$base.pdf',
        route: route,
        notes: const ['Produced by an external office engine.'],
      );
    }
    switch (route.to) {
      case OfficeFormat.pdf:
        if (route.from == OfficeFormat.html || route.from == OfficeFormat.txt) {
          // Plain-text inputs never enter the office reader, which only
          // understands office containers.
          final isHtml = route.from == OfficeFormat.html;
          final text = isHtml
              ? htmlToText(bytes)
              : utf8.decode(bytes, allowMalformed: true);
          final pdf = await buildOfficePdf(
            _textDocument(text, isHtml ? 'HTML document' : 'Text document'),
          );
          _assertPdf(pdf);
          return OfficeConversion(
            bytes: pdf,
            format: OfficeFormat.pdf,
            fileName: '$base.pdf',
            route: route,
            notes: isHtml
                ? const ['HTML styling, images and scripts were not rendered.']
                : const [],
          );
        }
        final document = await compute(
          _readForConversion,
          _ReadRequest(bytes, sourceName),
        );
        final pdf = await buildOfficePdf(document);
        _assertPdf(pdf);
        return OfficeConversion(
          bytes: pdf,
          format: OfficeFormat.pdf,
          fileName: '$base.pdf',
          route: route,
          notes: document.notes,
        );
      case OfficeFormat.odt:
        final document = await compute(
          _readForConversion,
          _ReadRequest(bytes, sourceName),
        );
        final odt = writeOdt(document);
        return OfficeConversion(
          bytes: odt,
          format: OfficeFormat.odt,
          fileName: '$base.odt',
          route: route,
          notes: document.notes,
        );
      case OfficeFormat.ods:
        final document = await compute(
          _readForConversion,
          _ReadRequest(bytes, sourceName),
        );
        final ods = writeOds(document);
        return OfficeConversion(
          bytes: ods,
          format: OfficeFormat.ods,
          fileName: '$base.ods',
          route: route,
          notes: document.notes,
        );
      case OfficeFormat.txt:
        final output = await compute(
          _writeText,
          _TextRequest(bytes, sourceName, csv: route == _spreadsheetToCsv),
        );
        return OfficeConversion(
          bytes: output.bytes,
          format: OfficeFormat.txt,
          fileName: '$base.${route == _spreadsheetToCsv ? 'csv' : 'txt'}',
          route: route,
          notes: output.notes,
        );
      default:
        throw UnsupportedError('This build cannot write ${route.to.label}.');
    }
  }

  static void _assertPdf(Uint8List bytes) {
    const header = [0x25, 0x50, 0x44, 0x46];
    if (bytes.length < 5) {
      throw const FormatException('The PDF engine produced no output.');
    }
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) {
        throw const FormatException(
          'The PDF engine produced an invalid file and it was discarded.',
        );
      }
    }
  }

  static String _baseName(String? sourceName) {
    if (sourceName == null || sourceName.trim().isEmpty) return 'desksuite';
    final name = sourceName.split('/').last.split(r'\').last;
    final dot = name.lastIndexOf('.');
    final base = dot <= 0 ? name : name.substring(0, dot);
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    return cleaned.isEmpty ? 'desksuite' : cleaned;
  }
}

class _ReadRequest {
  const _ReadRequest(this.bytes, this.name);
  final Uint8List bytes;
  final String? name;
}

OfficeDocument _readForConversion(_ReadRequest request) =>
    readOfficeDocument(request.bytes, fileName: request.name);

class _TextRequest {
  const _TextRequest(this.bytes, this.name, {required this.csv});
  final Uint8List bytes;
  final String? name;
  final bool csv;
}

class _TextOutput {
  const _TextOutput(this.bytes, this.notes);
  final Uint8List bytes;
  final List<String> notes;
}

_TextOutput _writeText(_TextRequest request) {
  final detected = detectOfficeFile(request.bytes, fileName: request.name);
  if (detected.format == OfficeFormat.txt) {
    return _TextOutput(request.bytes, const []);
  }
  if (detected.format == OfficeFormat.html) {
    return _TextOutput(
      Uint8List.fromList(utf8.encode(htmlToText(request.bytes))),
      const ['HTML styling, images and scripts were not rendered.'],
    );
  }
  final document = readOfficeDocument(request.bytes, fileName: request.name);
  if (request.csv) {
    final buffer = StringBuffer();
    for (final block in document.blocks) {
      if (block.kind == OfficeBlockKind.row) {
        buffer.writeln(block.cells.map(_csvField).join(','));
      } else if (block.kind == OfficeBlockKind.paragraph &&
          document.blocks.indexOf(block) > 0) {
        buffer.writeln('# Sheet: ${block.text}');
      }
    }
    return _TextOutput(
      Uint8List.fromList(utf8.encode(buffer.toString())),
      document.notes,
    );
  }
  final text = document.plainText.isEmpty
      ? document.tableText
      : document.tableText.isEmpty
      ? document.plainText
      : '${document.plainText}\n\n${document.tableText}';
  return _TextOutput(
    Uint8List.fromList(utf8.encode(text.endsWith('\n') ? text : '$text\n')),
    document.notes,
  );
}

OfficeDocument _textDocument(String text, String title) => OfficeDocument(
  format: OfficeFormat.txt,
  title: title,
  blocks: [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) OfficeBlock.paragraph(line),
  ],
);

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
