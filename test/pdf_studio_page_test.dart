import 'dart:typed_data';

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
    TextButton(
      key: const Key('stub-bad-split'),
      onPressed: () =>
          onSplitPages([bytes, Uint8List.fromList('not a pdf'.codeUnits)]),
      child: const Text('bad split'),
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

  testWidgets('invalid split output is refused before writing any part', (
    tester,
  ) async {
    final picker = FakePicker((bytes: twoPages, name: 'contract.pdf'));
    final files = RecordingFiles();
    await open(tester, picker, files);

    await tester.tap(find.byKey(const Key('stub-bad-split')));
    await _settle(tester);
    expect(files.names, isEmpty);
    expect(find.textContaining('no files were written'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling split stops without opening another save', (
    tester,
  ) async {
    final picker = FakePicker((bytes: twoPages, name: 'contract.pdf'));
    final files = RecordingFiles()..accept = false;
    await open(tester, picker, files);

    await tester.tap(find.byKey(const Key('stub-split')));
    await _settle(tester);
    expect(files.names, ['contract-part-1.pdf']);
    expect(find.textContaining('Wrote 0 of 2 file(s)'), findsOneWidget);
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
    expect(find.textContaining('Unsaved changes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pdf-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.text('editor:a'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pdf-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pdf-discard-changes')));
    await tester.pumpAndSettle();
    expect(find.text('editor:a'), findsNothing);
    expect(find.byKey(const Key('pdf-open')), findsOneWidget);
  });

  testWidgets('opening another PDF asks before discarding editor state', (
    tester,
  ) async {
    final picker = FakePicker((bytes: onePage, name: 'first.pdf'));
    final files = RecordingFiles();
    await open(tester, picker, files);
    picker.result = (bytes: twoPages, name: 'second.pdf');

    await tester.tap(find.byKey(const Key('pdf-open-another')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pdf-keep-editing')));
    await tester.pumpAndSettle();
    expect(picker.calls, 1);
    expect(find.text('editor:first'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pdf-open-another')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pdf-discard-changes')));
    await _settle(tester);
    expect(picker.calls, 2);
    expect(find.text('editor:second'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
