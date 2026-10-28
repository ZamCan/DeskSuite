import 'dart:typed_data';

import 'package:desksuite/pdf/pdf_inspection.dart';
import 'package:desksuite/pdf/pdf_studio_page.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> _pdf(int pages) async {
  final document = pw.Document();
  for (var i = 0; i < pages; i++) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Text('Page ${i + 1}'),
      ),
    );
  }
  return document.save();
}

class FakePicker implements DocumentPicker {
  FakePicker(this.result);
  PickedDocument? result;
  int calls = 0;

  @override
  Future<PickedDocument?> pickDocument() async {
    calls++;
    return result;
  }
}

/// Hands out documents in order and then reports "the user cancelled", which
/// is how the combine dialog ends: it is dismissed or the picker is backed out
/// of.
class QueuePicker implements DocumentPicker {
  QueuePicker(this.queue);
  final List<PickedDocument> queue;
  int calls = 0;

  @override
  Future<PickedDocument?> pickDocument() async {
    calls++;
    if (queue.isEmpty) return null;
    return queue.removeAt(0);
  }
}

class RecordingFiles extends _FilesBase {}

abstract class _FilesBase implements FileGateway {
  Uint8List? bytes;
  String? name;
  final List<String> names = [];
  bool accept = true;

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
    names.add(name);
    this.name = name;
    this.bytes = bytes;
    return accept;
  }
}

/// A stand-in editor: it emits whatever the test asks for, so the screen's
/// inspect/validate/save logic is exercised without rendering a PDF.
Widget _stubEditor(
  Uint8List bytes, {
  required String documentId,
  required ValueChanged<Uint8List> onSave,
  required ValueChanged<Uint8List> onExportPages,
  required ValueChanged<List<Uint8List>> onSplitPages,
}) => Column(
  children: [
    Text('editor:$documentId'),
    TextButton(
      key: const Key('stub-save'),
      onPressed: () => onSave(bytes),
      child: const Text('save'),
    ),
    TextButton(
      key: const Key('stub-bad-save'),
      onPressed: () => onSave(Uint8List.fromList('not a pdf'.codeUnits)),
      child: const Text('bad save'),
    ),
    TextButton(
      key: const Key('stub-export'),
      onPressed: () => onExportPages(bytes),
      child: const Text('export pages'),
    ),
    TextButton(
      key: const Key('stub-split'),
      onPressed: () => onSplitPages([bytes, bytes]),
      child: const Text('split'),
    ),
  ],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  late Uint8List twoPages;
  late Uint8List onePage;

  setUpAll(() async {
    twoPages = await _pdf(2);
    onePage = await _pdf(1);
  });

  Future<void> open(
    WidgetTester tester,
    FakePicker picker,
    RecordingFiles files,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfStudioPage(
            picker: picker,
            files: files,
            editorBuilder: _stubEditor,
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const Key('pdf-open')));
    await _settle(tester);
  }

  testWidgets('combines two real PDFs into one new file', (tester) async {
    tester.view.physicalSize = const Size(380, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = RecordingFiles();
    final picker = QueuePicker([
      (bytes: onePage, name: '/tmp/Cover.pdf'),
      (bytes: twoPages, name: '/tmp/Report.pdf'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfStudioPage(
            picker: picker,
            files: files,
            editorBuilder: _stubEditor,
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('pdf-combine')));
    await _settle(tester);
    expect(find.text('No PDFs added yet.'), findsOneWidget);
    // Two documents are required before the action is offered.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('combine-save')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('combine-add')));
    await _settle(tester);
    expect(find.byKey(const Key('combine-row-0')), findsOneWidget);
    expect(find.text('1 file(s) · 1 page(s)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('combine-add')));
    await _settle(tester);
    expect(find.byKey(const Key('combine-row-1')), findsOneWidget);
    expect(find.text('2 file(s) · 3 page(s)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('combine-save')));
    await _settle(tester);

    expect(files.names, ['Cover-combined.pdf']);
    final written = files.bytes;
    expect(written, isNotNull);
    // The written file really is a four-page... here three-page PDF.
    final inspection = inspectPdf(written!);
    expect(inspection.pageCount, 3);
    expect(
      find.textContaining('Combined 2 PDFs into Cover-combined.pdf'),
      findsOneWidget,
    );
  });

  testWidgets('a cancelled combine writes nothing and says so', (tester) async {
    tester.view.physicalSize = const Size(380, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = RecordingFiles();
    final picker = QueuePicker([(bytes: onePage, name: 'a.pdf')]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfStudioPage(
            picker: picker,
            files: files,
            editorBuilder: _stubEditor,
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('pdf-combine')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('combine-add')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('combine-cancel')));
    await _settle(tester);

    expect(files.names, isEmpty);
    expect(find.textContaining('Combining cancelled'), findsOneWidget);
  });

  testWidgets('a non-PDF added to a combine is refused with a reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = RecordingFiles();
    final picker = QueuePicker([
      (bytes: Uint8List.fromList('not a pdf'.codeUnits), name: 'notes.txt'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfStudioPage(
            picker: picker,
            files: files,
            editorBuilder: _stubEditor,
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('pdf-combine')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('combine-add')));
    await _settle(tester);

    expect(find.byKey(const Key('combine-error')), findsOneWidget);
    expect(find.byKey(const Key('combine-row-0')), findsNothing);
    expect(files.names, isEmpty);
  });

  testWidgets('a file can be taken back out of a combine', (tester) async {
    tester.view.physicalSize = const Size(380, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = RecordingFiles();
    final picker = QueuePicker([
      (bytes: onePage, name: 'a.pdf'),
      (bytes: twoPages, name: 'b.pdf'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfStudioPage(
            picker: picker,
            files: files,
            editorBuilder: _stubEditor,
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('pdf-combine')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('combine-add')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('combine-add')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('combine-remove-0')));
    await _settle(tester);

    expect(find.byKey(const Key('combine-row-1')), findsNothing);
    expect(find.text('1 file(s) · 2 page(s)'), findsOneWidget);
    expect(files.names, isEmpty);
  });

  testWidgets('opens a real PDF, reports its pages and saves an edited copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final picker = FakePicker((bytes: twoPages, name: '/tmp/My Report.pdf'));
    final files = RecordingFiles();
    await open(tester, picker, files);

    expect(find.textContaining('2 page(s)'), findsWidgets);
    expect(find.text('editor:My-Report'), findsOneWidget);
    expect(find.textContaining('Opened read-only'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stub-save')));
    await _settle(tester);

    expect(files.name, 'My-Report-edited.pdf');
    expect(String.fromCharCodes(files.bytes!.take(5)), '%PDF-');
    expect(find.textContaining('Edited copy written'), findsOneWidget);
    expect(find.textContaining('2 page(s)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an editor that returns garbage is refused, not written', (
    tester,
  ) async {
    final picker = FakePicker((bytes: twoPages, name: 'report.pdf'));
    final files = RecordingFiles();
    await open(tester, picker, files);

    await tester.tap(find.byKey(const Key('stub-bad-save')));
    await _settle(tester);

    expect(files.names, isEmpty);
    expect(find.textContaining('not a PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page export and split write separate files with real names', (
    tester,
  ) async {
    final picker = FakePicker((bytes: twoPages, name: 'contract.pdf'));
    final files = RecordingFiles();
    await open(tester, picker, files);

    await tester.tap(find.byKey(const Key('stub-export')));
    await _settle(tester);
    expect(files.names, ['contract-pages.pdf']);

    await tester.tap(find.byKey(const Key('stub-split')));
    await _settle(tester);
    expect(files.names, [
      'contract-pages.pdf',
      'contract-part-1.pdf',
      'contract-part-2.pdf',
    ]);
    expect(find.textContaining('Split into 2 file(s)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled save is reported as cancelled, never as success', (
    tester,
  ) async {
    final picker = FakePicker((bytes: onePage, name: 'letter.pdf'));
    final files = RecordingFiles()..accept = false;
    await open(tester, picker, files);

    await tester.tap(find.byKey(const Key('stub-save')));
    await _settle(tester);

    expect(find.textContaining('Export cancelled'), findsOneWidget);
    // The cancelled message itself contains "written", so assert on the
    // success wording instead of the word alone.
    expect(find.textContaining('Written'), findsNothing);
    expect(find.textContaining('written ·'), findsNothing);
  });

  testWidgets('a non-PDF file is refused with an actionable message', (
    tester,
  ) async {
    final picker = FakePicker((
      bytes: Uint8List.fromList('hello'.codeUnits),
      name: 'notes.txt',
    ));
    final files = RecordingFiles();
    await open(tester, picker, files);

    expect(find.textContaining('not a PDF'), findsOneWidget);
    expect(find.textContaining('Document converter'), findsOneWidget);
    expect(find.byKey(const Key('pdf-open')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the picker keeps the previous state and says so', (
    tester,
  ) async {
    final picker = FakePicker(null);
    final files = RecordingFiles();
    await open(tester, picker, files);

    expect(picker.calls, 1);
    expect(find.textContaining('No file was chosen'), findsOneWidget);
    expect(find.byKey(const Key('pdf-open')), findsOneWidget);
  });

  testWidgets('closing a PDF returns to the open screen', (tester) async {
    final picker = FakePicker((bytes: onePage, name: 'a.pdf'));
    final files = RecordingFiles();
    await open(tester, picker, files);
    expect(find.text('editor:a'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pdf-close')));
    await tester.pumpAndSettle();
    expect(find.text('editor:a'), findsNothing);
    expect(find.byKey(const Key('pdf-open')), findsOneWidget);
  });

  group('pdfBaseName', () {
    test('strips directories, extension and unsafe characters', () {
      expect(pdfBaseName('/sdcard/Download/My Report.pdf'), 'My-Report');
      expect(pdfBaseName(r'C:\Users\a\notes v2.PDF'), 'notes-v2');
      expect(pdfBaseName('../../etc/passwd'), 'passwd');
      expect(pdfBaseName('...pdf'), 'document');
      expect(pdfBaseName('   '), 'document');
      expect(pdfBaseName('.hidden'), 'hidden');
    });

    test('clamps very long names instead of failing the save', () {
      final long = pdfBaseName('${'a' * 200}.pdf');
      expect(long.length, 60);
    });
  });
}
