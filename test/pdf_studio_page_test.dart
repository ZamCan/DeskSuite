import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:desksuite/pdf/pdf_studio_page.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfPicker implements DocumentPicker {
  PdfPicker(this.picked);
  PickedDocument? picked;

  @override
  Future<PickedDocument?> pickDocument() async => picked;
}

class PdfFiles implements FileGateway {
  String? savedName;
  Uint8List? savedBytes;
  String? savedMime;

  @override
  Future<Uint8List?> pickImage() async => null;

  @override
  Future<Uint8List?> pickProject() async => null;

  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    savedName = name;
    savedBytes = Uint8List.fromList(bytes);
    savedMime = mimeType;
    return true;
  }
}

Future<Uint8List> samplePdf() async {
  final document = pw.Document();
  document.addPage(
    pw.Page(
      build: (_) => pw.Center(child: pw.Text('DeskSuite PDF test')),
    ),
  );
  return document.save();
}

void main() {
  testWidgets('rejects non-PDF files instead of passing them to the editor', (
    tester,
  ) async {
    final files = PdfFiles();
    await tester.pumpWidget(
      MaterialApp(
        home: PdfStudioPage(
          picker: PdfPicker((
            bytes: Uint8List.fromList('not a PDF'.codeUnits),
            name: 'notes.txt',
          )),
          files: files,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('pdf-studio-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Choose an existing PDF file'), findsOneWidget);
    expect(find.byType(PdfEditorView), findsNothing);
    expect(files.savedBytes, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a real PDF in the offline editor without changing it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = await samplePdf();
    final untouched = Uint8List.fromList(source);
    final files = PdfFiles();
    await tester.pumpWidget(
      MaterialApp(
        home: PdfStudioPage(
          picker: PdfPicker((bytes: source, name: 'invoice.pdf')),
          files: files,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('pdf-studio-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PdfEditorView), findsOneWidget);
    expect(find.textContaining('invoice'), findsWidgets);
    expect(source, orderedEquals(untouched));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects oversized PDFs before allocating an editor copy', (
    tester,
  ) async {
    final oversized = Uint8List(48 * 1024 * 1024 + 1);
    oversized.setRange(0, 5, '%PDF-'.codeUnits);
    final files = PdfFiles();
    await tester.pumpWidget(
      MaterialApp(
        home: PdfStudioPage(
          picker: PdfPicker((bytes: oversized, name: 'large.pdf')),
          files: files,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('pdf-studio-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('larger than the 48 MB local editing limit'),
      findsOneWidget,
    );
    expect(find.byType(PdfEditorView), findsNothing);
    expect(files.savedBytes, isNull);
    expect(tester.takeException(), isNull);
  });
}
