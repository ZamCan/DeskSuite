import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:desksuite/ocr/ocr_engine.dart';
import 'package:desksuite/ocr/text_extraction_page.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/reveal.dart';

class CapturingFiles implements FileGateway {
  Uint8List? picked;
  String? savedName;
  String? savedMime;
  Uint8List? savedBytes;
  bool cancelled = false;

  @override
  Future<Uint8List?> pickImage() async => picked;

  @override
  Future<Uint8List?> pickProject() async => null;

  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    savedName = name;
    savedMime = mimeType;
    savedBytes = bytes;
    return !cancelled;
  }
}

class FakeEngine implements OcrEngine {
  FakeEngine({this.available = true, this.result, this.error});
  final bool available;
  final OcrResult? result;
  final Object? error;
  String? usedLanguage;

  @override
  String get label => 'Test recognizer';

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<String>> availableLanguages() async => const ['eng', 'swa'];

  @override
  Future<OcrResult> recognize({
    required Uint8List imageBytes,
    String language = 'eng',
  }) async {
    usedLanguage = language;
    if (error != null) throw error!;
    return result ?? OcrResult.empty;
  }
}

Uint8List sampleImage() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30)));

OcrResult recognized() => const OcrResult(
  text: 'TAARIFA YA MALIPO\nJumla 5,000',
  words: <OcrWord>[
    OcrWord(
      text: 'TAARIFA',
      left: 4,
      top: 4,
      right: 30,
      bottom: 10,
      confidence: 90,
    ),
    OcrWord(
      text: 'MALIPO',
      left: 31,
      top: 4,
      right: 38,
      bottom: 10,
      confidence: 85,
    ),
  ],
  imageWidth: 40,
  imageHeight: 30,
  language: 'eng',
  meanConfidence: 87.5,
);

Widget host({
  required OcrEngine engine,
  required CapturingFiles files,
  required Uint8List sample,
  Uint8List? initialImage,
  Future<Uint8List> Function(Uint8List)? prepare,
}) => MaterialApp(
  home: Scaffold(
    body: TextExtractionPage(
      files: files,
      engine: engine,
      sampleLoader: () async => sample,
      initialImage: initialImage,
      prepare: prepare ?? (bytes) async => bytes,
    ),
  ),
);

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selected scan page loads without automatically recognizing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine(result: recognized());
    final bytes = sampleImage();
    await tester.pumpWidget(
      host(
        engine: engine,
        files: CapturingFiles(),
        sample: bytes,
        initialImage: bytes,
      ),
    );
    await settle(tester);
    expect(find.text('Selected scan page'), findsOneWidget);
    expect(find.byKey(const Key('ocr-preview')), findsOneWidget);
    expect(engine.usedLanguage, isNull);
    await reveal(tester, find.byKey(const Key('ocr-run')));
    await tester.tap(find.byKey(const Key('ocr-run')));
    await settle(tester);
    expect(engine.usedLanguage, 'eng');
    expect(find.byKey(const Key('ocr-summary')), findsOneWidget);
  });

  testWidgets(
    'failed preparation cannot recognize the previous page by mistake',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final files = CapturingFiles()..picked = sampleImage();
      final engine = FakeEngine(result: recognized());
      var failNext = false;
      await tester.pumpWidget(
        host(
          engine: engine,
          files: files,
          sample: sampleImage(),
          prepare: (bytes) async {
            if (failNext) throw const FormatException('Bad image.');
            return bytes;
          },
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('ocr-sample')));
      await settle(tester);
      expect(find.byKey(const Key('ocr-preview')), findsOneWidget);
      failNext = true;
      await tester.tap(find.byKey(const Key('ocr-choose')));
      await settle(tester);
      expect(
        find.textContaining('This image could not be prepared'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ocr-preview')), findsNothing);
      await reveal(tester, find.byKey(const Key('ocr-run')));
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('ocr-run'))).onPressed,
        isNull,
      );
      expect(engine.usedLanguage, isNull);
    },
  );

  testWidgets('extracts, reviews and exports recognized text', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final files = CapturingFiles();
    final engine = FakeEngine(result: recognized());
    await tester.pumpWidget(
      host(engine: engine, files: files, sample: sampleImage()),
    );
    await settle(tester);
    expect(find.text('Offline recognizer ready'), findsOneWidget);

    await reveal(tester, find.byKey(const Key('ocr-sample')));

    await tester.tap(find.byKey(const Key('ocr-sample')));
    await settle(tester);
    expect(find.byKey(const Key('ocr-preview')), findsOneWidget);

    await reveal(tester, find.byKey(const Key('ocr-run')));

    await tester.tap(find.byKey(const Key('ocr-run')));
    await settle(tester);
    expect(find.byKey(const Key('ocr-summary')), findsOneWidget);
    await reveal(tester, find.byKey(const Key('ocr-text')));
    final field = tester.widget<TextField>(find.byKey(const Key('ocr-text')));
    expect(field.controller!.text, contains('TAARIFA YA MALIPO'));
    expect(field.controller!.text, contains('Jumla 5,000'));

    // A corrected word must be what gets exported.
    await tester.enterText(
      find.byKey(const Key('ocr-text')),
      'TAARIFA YA MALIPO\nJumla 5,500',
    );
    await reveal(tester, find.byKey(const Key('ocr-txt')));
    await tester.tap(find.byKey(const Key('ocr-txt')));
    await settle(tester);
    expect(files.savedName, 'desksuite-extracted-text.txt');
    expect(files.savedMime, 'text/plain');
    expect(utf8.decode(files.savedBytes!), contains('Jumla 5,500'));

    await reveal(tester, find.byKey(const Key('ocr-docx')));

    await tester.tap(find.byKey(const Key('ocr-docx')));
    await settle(tester);
    expect(files.savedName, 'desksuite-extracted-text.docx');
    final archive = ZipDecoder().decodeBytes(files.savedBytes!);
    final document = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'word/document.xml').content
          as List<int>,
    );
    expect(document, contains('Jumla 5,500'));

    await reveal(tester, find.byKey(const Key('ocr-pdf')));

    await tester.tap(find.byKey(const Key('ocr-pdf')));
    await settle(tester);
    expect(find.text('PDF layer uses original OCR'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await settle(tester);
    expect(files.savedName, 'desksuite-extracted-text.docx');
    await tester.tap(find.byKey(const Key('ocr-pdf')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('ocr-confirm-original-layer')));
    await settle(tester);
    expect(files.savedName, 'desksuite-searchable.pdf');
    expect(files.savedMime, 'application/pdf');
    expect(latin1.decode(files.savedBytes!.sublist(0, 5)), '%PDF-');
    expect(tester.takeException(), isNull);
  });

  testWidgets('passes the selected language to the engine', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = FakeEngine(result: recognized());
    await tester.pumpWidget(
      host(engine: engine, files: CapturingFiles(), sample: sampleImage()),
    );
    await settle(tester);
    await reveal(tester, find.byKey(const Key('ocr-sample')));
    await tester.tap(find.byKey(const Key('ocr-sample')));
    await settle(tester);
    await reveal(tester, find.byKey(const Key('ocr-language')));
    await tester.tap(find.byKey(const Key('ocr-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English + Kiswahili').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('ocr-run')));
    await tester.tap(find.byKey(const Key('ocr-run')));
    await settle(tester);
    expect(engine.usedLanguage, 'eng+swa');
  });

  testWidgets('disables recognition when no engine is available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        engine: FakeEngine(available: false),
        files: CapturingFiles(),
        sample: sampleImage(),
      ),
    );
    await settle(tester);
    expect(
      find.text('Recognition is not available on this build'),
      findsOneWidget,
    );
    await reveal(tester, find.byKey(const Key('ocr-sample')));
    await tester.tap(find.byKey(const Key('ocr-sample')));
    await settle(tester);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('ocr-run')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('shows a recognition failure instead of an empty result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        engine: FakeEngine(error: const OcrFailure('Model could not load.')),
        files: CapturingFiles(),
        sample: sampleImage(),
      ),
    );
    await settle(tester);
    await reveal(tester, find.byKey(const Key('ocr-sample')));
    await tester.tap(find.byKey(const Key('ocr-sample')));
    await settle(tester);
    await reveal(tester, find.byKey(const Key('ocr-run')));
    await tester.tap(find.byKey(const Key('ocr-run')));
    await settle(tester);
    expect(find.text('Model could not load.'), findsOneWidget);
    expect(find.byKey(const Key('ocr-text')), findsNothing);
  });

  testWidgets('reports a cancelled save without claiming success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final files = CapturingFiles()..cancelled = true;
    await tester.pumpWidget(
      host(
        engine: FakeEngine(result: recognized()),
        files: files,
        sample: sampleImage(),
      ),
    );
    await settle(tester);
    await reveal(tester, find.byKey(const Key('ocr-sample')));
    await tester.tap(find.byKey(const Key('ocr-sample')));
    await settle(tester);
    await reveal(tester, find.byKey(const Key('ocr-run')));
    await tester.tap(find.byKey(const Key('ocr-run')));
    await settle(tester);
    await reveal(tester, find.byKey(const Key('ocr-txt')));
    await tester.tap(find.byKey(const Key('ocr-txt')));
    await settle(tester);
    // The status card sits at the top of the list, which may have been scrolled
    // away when the export button was tapped.
    await reveal(tester, find.textContaining('Save cancelled'));
    expect(find.textContaining('Save cancelled'), findsOneWidget);
  });
}
