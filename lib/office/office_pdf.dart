import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'office_reader.dart';

/// Renders a readable [OfficeDocument] into a real PDF with selectable text.
///
/// This is a content renderer: it produces clean, printable pages from the
/// text, headings, emphasis and table rows that were read. It is not a
/// pixel-accurate reproduction of the original application's layout, and the
/// document notes state that plainly.
Future<Uint8List> buildOfficePdf(
  OfficeDocument document, {
  PdfPageFormat format = PdfPageFormat.a4,
  pw.Font? regular,
  pw.Font? bold,
}) async {
  if (document.blocks.isEmpty) {
    throw const FormatException('The document has no readable content.');
  }
  final theme = await deskSuitePdfTheme(regular: regular, bold: bold);
  final pdf = pw.Document(
    title: document.title,
    author: 'DeskSuite (ZamCan)',
    creator: 'DeskSuite office reader',
    theme: theme,
  );
  final body = theme.defaultTextStyle;
  final boldStyle = theme.header1;
  final heading = body.copyWith(
    font: boldStyle.font,
    fontWeight: pw.FontWeight.bold,
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                document.title,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: body.copyWith(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          document.title,
          style: heading.copyWith(fontSize: 20, color: PdfColors.grey900),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${document.format.label} - ${document.format.description}',
          style: body.copyWith(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 18),
        ..._buildBlocks(document.blocks, body, heading),
        if (document.notes.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey400, thickness: .5),
          pw.Text('Conversion notes', style: heading.copyWith(fontSize: 9)),
          pw.SizedBox(height: 4),
          for (final note in document.notes)
            pw.Bullet(
              bulletSize: 3,
              text: note,
              style: body.copyWith(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ],
    ),
  );
  return pdf.save();
}

List<pw.Widget> _buildBlocks(
  List<OfficeBlock> blocks,
  pw.TextStyle body,
  pw.TextStyle heading,
) {
  final widgets = <pw.Widget>[];
  var previousWasRow = false;
  final pendingRows = <OfficeBlock>[];

  void flushRows() {
    if (pendingRows.isEmpty) return;
    final rows = List<OfficeBlock>.from(pendingRows);
    pendingRows.clear();
    widgets.add(
      pw.TableHelper.fromTextArray(
        headers: null,
        data: [for (final row in rows) row.cells],
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .4),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        headerStyle: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
        cellAlignment: pw.Alignment.centerLeft,
      ),
    );
    widgets.add(pw.SizedBox(height: 8));
    previousWasRow = false;
  }

  for (final block in blocks) {
    if (block.kind == OfficeBlockKind.row) {
      pendingRows.add(block);
      previousWasRow = true;
      continue;
    }
    if (previousWasRow) flushRows();
    switch (block.kind) {
      case OfficeBlockKind.pageBreak:
        widgets.add(pw.NewPage());
      case OfficeBlockKind.paragraph:
        final size = switch (block.headingLevel) {
          0 => 10.5,
          1 => 17.0,
          2 => 14.5,
          3 => 12.5,
          _ => 11.5,
        };
        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(
              top: block.headingLevel == 1 ? 14 : 6,
              bottom: 4,
            ),
            child: pw.Text(
              block.text,
              style: (block.headingLevel > 0 || block.bold ? heading : body)
                  .copyWith(
                    fontSize: size,
                    fontStyle: block.italic
                        ? pw.FontStyle.italic
                        : pw.FontStyle.normal,
                  ),
            ),
          ),
        );
      case OfficeBlockKind.row:
        break;
    }
  }
  if (previousWasRow) flushRows();
  return widgets;
}

/// A PDF theme that can draw accents, smart quotes, dashes and non-Latin text.
///
/// The bundled Noto Sans (OFL-1.1) is embedded as a subset so generated PDFs do
/// not silently drop glyphs the way the built-in Helvetica does. If the asset is
/// unavailable (for example in a unit test without the bundle), the theme falls
/// back to the PDF built-ins instead of failing the conversion.
final Map<String, pw.ThemeData> _themeCache = {};

Future<pw.ThemeData> deskSuitePdfTheme({
  pw.Font? regular,
  pw.Font? bold,
}) async {
  if (regular != null && bold != null) {
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }
  final cached = _themeCache['default'];
  if (cached != null) return cached;
  try {
    final base = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final theme = pw.ThemeData.withFont(base: base, bold: boldFont);
    _themeCache['default'] = theme;
    return theme;
  } catch (_) {
    final theme = pw.ThemeData.base();
    _themeCache['default'] = theme;
    return theme;
  }
}
