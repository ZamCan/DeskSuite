import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/core/atomic_file_store.dart';
import 'package:desksuite/document_scan/camera_gateway.dart';
import 'package:desksuite/document_scan/document_cleanup.dart';
import 'package:desksuite/document_scan/scan_draft_store.dart';
import 'package:desksuite/document_scan/scan_pdf.dart';
import 'package:desksuite/document_scan/scan_processor.dart';
import 'package:desksuite/document_scan/scan_studio_page.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

import 'package:image/image.dart' as img;

class ScanFiles implements FileGateway {
  ScanFiles(this.imported);
  final Uint8List imported;
  Uint8List? exported;
  String? name;
  @override
  Future<Uint8List?> pickImage() async => imported;
  @override
  Future<Uint8List?> pickProject() async => null;
  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    this.name = name;
    exported = bytes;
    return true;
  }
}

class ScanCamera implements CameraGateway {
  ScanCamera(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List?> capture() async => bytes;
  @override
  Future<Uint8List?> retrieveLostCapture() async => bytes;
}

Future<void> waitIo(
  WidgetTester tester, {
  int rounds = 25,
  Finder? until,
}) async {
  if (until != null) {
    await settleUntil(tester, until);
    return;
  }
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

/// Reads the draft store without ever hanging the test.
///
/// The store's read/write queue is created in the fake-async zone, so awaiting a
/// read inside runAsync can deadlock on a slower machine: the future completes
/// but its continuation is scheduled back into a zone that only advances on
/// pump. This bounds each attempt in real time and reports a failure instead of
/// letting the suite sit until the ten-minute test timeout.
Future<List<ScanDraftPage>> readDraft(
  WidgetTester tester,
  ScanDraftStore store,
) async {
  Object? error;
  for (var attempt = 0; attempt < 40; attempt++) {
    List<ScanDraftPage>? pages;
    await tester.runAsync(() async {
      try {
        pages = await store.load().timeout(const Duration(milliseconds: 500));
      } catch (e) {
        error = e;
      }
    });
    if (pages != null) return pages!;
    if (error is FormatException) throw error!;
    await tester.pump(const Duration(milliseconds: 25));
  }
  fail('The scan draft could not be read back within 20 seconds: $error');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 25,
    );
  }
  // A control that is disabled because a page is still being processed ignores
  // the tap, and the caller then waits for a result that cannot arrive yet.
  // Waiting first also settles the layout: the busy row disappears, the list
  // changes height, and a position measured before that is already stale.
  await settleUntilEnabled(tester, finder);
  await tester.ensureVisible(finder);
  // pumpAndSettle never returns while an indeterminate progress animation is
  // running, and its default budget is ten minutes; pump a bounded number of
  // frames instead, which is enough for a route or dialog animation.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  await tester.tap(finder);
  // A running indeterminate progress indicator cannot settle until real I/O
  // completes; give routes time to animate and let callers wait for I/O.
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  late Directory temp;
  late ScanDraftStore store;
  late ScanFiles files;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('desksuite-scan-widget-');
    store = ScanDraftStore(Directory('${temp.path}/draft'));
    final source = img.Image(width: 80, height: 60);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, x * 3, y * 4, 0);
      }
    }
    files = ScanFiles(Uint8List.fromList(img.encodePng(source)));
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Widget screen({CameraGateway? camera, Uint8List? recovered}) => MaterialApp(
    home: Scaffold(
      body: ScanStudioPage(
        files: files,
        camera: camera,
        recoveredCapture: recovered,
        storeFactory: () async => store,
        photoProcessor: (request) async => processPhoto(request),
        scanProcessor: (request) async => processScan(request),
        cleanupProcessor: (request) async => processDocumentCleanup(request),
        pdfGenerator: createScanPdf,
      ),
    ),
  );

  testWidgets(
    'import, correct, rotate, reset, save draft and export a real PDF',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final untouched = Uint8List.fromList(files.imported);
      await tester.pumpWidget(screen());
      await waitIo(tester);
      await tapVisible(tester, find.byKey(const Key('scan-import')));
      await waitIo(tester);
      // The page count is the app's own signal that the draft was loaded; wait
      // for it instead of assuming a fixed number of pumps was enough.
      await settleUntil(tester, find.textContaining('1 of 8 pages'));
      expect(find.textContaining('1 of 8 pages'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('scan-crop')));
      await waitIo(tester, until: find.text('Adjust page corners'));
      expect(find.text('Adjust page corners'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('corner-0')),
        const Offset(40, 30),
      );
      await tester.pump();
      await tapVisible(tester, find.byKey(const Key('apply-corners')));
      await waitIo(tester);
      expect(find.text('Adjust page corners'), findsNothing);
      final cropped = (await readDraft(tester, store)).single.image;
      final corner = img.decodePng(cropped.bytes)!.getPixel(0, 0);
      expect(corner.r > 0 || corner.g > 0, isTrue);
      expect(find.byKey(const Key('scan-undo')), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('scan-rotate')));
      await waitIo(tester);
      final rotated = (await readDraft(tester, store)).single.image;
      expect([rotated.width, rotated.height], [cropped.height, cropped.width]);
      await tapVisible(tester, find.byKey(const Key('scan-reset')));
      await waitIo(tester);
      final stored = await readDraft(tester, store);
      expect(stored.single.image.width, 80);
      expect(stored.single.image.height, 60);
      await tapVisible(tester, find.byKey(const Key('scan-pdf')));
      await waitIo(tester);
      expect(find.text('PDF ready to save'), findsOneWidget);
      expect(find.textContaining('does not contain OCR'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('scan-save-pdf')));
      await waitIo(tester);
      expect(files.name, 'desksuite-document.pdf');
      expect(String.fromCharCodes(files.exported!.take(5)), '%PDF-');
      expect(files.imported, orderedEquals(untouched));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shadowed example compares real cleanup, preserves draft until applied, and exports',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(screen());
      await waitIo(tester);
      await tapVisible(tester, find.byKey(const Key('scan-samples')));
      await tapVisible(tester, find.byKey(const Key('sample-cleanup')));
      await waitIo(tester, rounds: 45);
      final before = (await readDraft(tester, store)).single;
      final original = Uint8List.fromList(before.original.bytes);

      await tapVisible(tester, find.byKey(const Key('scan-cleanup')));
      expect(find.byKey(const Key('cleanup-before-image')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('cleanup-use')))
            .onPressed,
        isNull,
      );
      await tapVisible(tester, find.byKey(const Key('cleanup-preview')));
      await waitIo(tester, rounds: 45);
      expect(find.byKey(const Key('cleanup-after-image')), findsOneWidget);
      expect(
        (await readDraft(tester, store)).single.image.bytes,
        orderedEquals(before.image.bytes),
      );
      await tapVisible(tester, find.byKey(const Key('cleanup-before')));
      expect(find.byKey(const Key('cleanup-before-image')), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('cleanup-after')));
      expect(find.byKey(const Key('cleanup-after-image')), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('cleanup-cancel')));
      expect(
        (await readDraft(tester, store)).single.image.bytes,
        orderedEquals(before.image.bytes),
      );

      await tapVisible(tester, find.byKey(const Key('scan-cleanup')));
      await tapVisible(tester, find.byKey(const Key('cleanup-mode')));
      await tapVisible(tester, find.text('Adaptive black & white').last);
      await tapVisible(tester, find.byKey(const Key('cleanup-preview')));
      await waitIo(tester, rounds: 45);
      await tapVisible(tester, find.byKey(const Key('cleanup-use')));
      await waitIo(tester, rounds: 45);
      final cleaned = (await readDraft(tester, store)).single;
      expect(cleaned.original.bytes, orderedEquals(original));
      expect(cleaned.image.bytes, isNot(orderedEquals(before.image.bytes)));
      expect(img.decodePng(cleaned.image.bytes)!.getPixel(30, 400).r, 255);
      await tapVisible(tester, find.text('Export page PNG'));
      await waitIo(tester);
      expect(files.exported, orderedEquals(cleaned.image.bytes));
      await tapVisible(tester, find.byKey(const Key('scan-pdf')));
      await waitIo(tester, rounds: 45);
      await tapVisible(tester, find.byKey(const Key('scan-save-pdf')));
      await waitIo(tester);
      expect(String.fromCharCodes(files.exported!.take(5)), '%PDF-');
      expect(find.byKey(const Key('scan-page-0')), findsOneWidget);
      expect(find.byKey(const Key('scan-undo')), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('scan-undo')));
      await waitIo(tester);
      expect(
        (await readDraft(tester, store)).single.image.bytes,
        orderedEquals(before.image.bytes),
      );
      await tapVisible(tester, find.byKey(const Key('scan-reset')));
      await waitIo(tester);
      expect(
        (await readDraft(tester, store)).single.image.bytes,
        orderedEquals(original),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bundled two-page tutorial runs the actual PDF pipeline and supports reordering',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(screen());
      await waitIo(tester);
      await tapVisible(tester, find.byKey(const Key('scan-samples')));
      await tapVisible(tester, find.byKey(const Key('sample-report')));
      await waitIo(tester, rounds: 45);
      // The page count is the app's own signal that the draft was loaded; wait
      // for it instead of assuming a fixed number of pumps was enough.
      await settleUntil(tester, find.textContaining('2 of 8 pages'));
      expect(find.textContaining('2 of 8 pages'), findsOneWidget);
      final initial = await readDraft(tester, store);
      expect(initial, hasLength(2));
      await tapVisible(tester, find.byKey(const Key('scan-move-down')));
      await waitIo(tester);
      final moved = await readDraft(tester, store);
      expect(moved.first.id, initial.last.id);
      await tapVisible(tester, find.byKey(const Key('scan-pdf')));
      await waitIo(tester, rounds: 45);
      expect(find.textContaining('2 page(s)'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('scan-save-pdf')));
      await waitIo(tester);
      expect(files.exported, isNotNull);
      expect(String.fromCharCodes(files.exported!.take(5)), '%PDF-');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reopening restores edited pages and their order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen());
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-samples')));
    await tapVisible(tester, find.byKey(const Key('sample-report')));
    await waitIo(tester, rounds: 45);
    await tapVisible(tester, find.byKey(const Key('scan-move-down')));
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-rotate')));
    await waitIo(tester, rounds: 45);
    final before = await readDraft(tester, store);
    expect(before, hasLength(2));
    final editedId = before.last.id;
    final editedBytes = Uint8List.fromList(before.last.image.bytes);
    expect(before.last.image.width, before.last.original.height);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(screen());
    await waitIo(tester, rounds: 45);
    // The page count is the app's own signal that the draft was loaded; wait
    // for it instead of assuming a fixed number of pumps was enough.
    await settleUntil(tester, find.textContaining('2 of 8 pages'));
    expect(find.textContaining('2 of 8 pages'), findsOneWidget);
    final reopened = await readDraft(tester, store);
    expect(reopened.map((page) => page.id), before.map((page) => page.id));
    expect(reopened.last.id, editedId);
    expect(reopened.last.image.bytes, orderedEquals(editedBytes));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed camera draft save keeps recovery and retry commits it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var failManifest = true;
    store = ScanDraftStore(
      Directory('${temp.path}/draft'),
      writeFile: (file, bytes) async {
        if (failManifest && file.path.endsWith('draft.json')) {
          throw const FileSystemException('Simulated full storage');
        }
        await replaceFileAtomically(file, bytes);
      },
    );
    final original = Uint8List.fromList(files.imported);
    await tester.pumpWidget(screen(camera: ScanCamera(files.imported)));
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-camera')));
    await waitIo(tester);
    expect(find.textContaining('Draft could not be saved'), findsOneWidget);
    expect(
      find.textContaining('camera image is in the unsaved draft'),
      findsOneWidget,
    );
    expect((await readDraft(tester, store)), isEmpty);
    await tapVisible(tester, find.text('Export recovered original'));
    await waitIo(tester);
    expect(files.exported, orderedEquals(original));
    failManifest = false;
    await tapVisible(tester, find.text('Retry saving draft'));
    await settleUntilGone(
      tester,
      find.textContaining('Draft could not be saved'),
    );
    expect(find.textContaining('Draft could not be saved'), findsNothing);
    expect(
      find.textContaining('camera image is in the unsaved draft'),
      findsNothing,
    );
    final saved = await readDraft(tester, store);
    expect(saved, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(screen());
    await waitIo(tester);
    // The page count is the app's own signal that the draft was loaded; wait
    // for it instead of assuming a fixed number of pumps was enough.
    await settleUntil(tester, find.textContaining('1 of 8 pages'));
    expect(find.textContaining('1 of 8 pages'), findsOneWidget);
    expect((await readDraft(tester, store)).single.id, saved.single.id);
    expect(files.imported, orderedEquals(original));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact phone and larger text keep corner controls usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: ScanStudioPage(
            files: files,
            storeFactory: () async => store,
            photoProcessor: (request) async => processPhoto(request),
            scanProcessor: (request) async => processScan(request),
            pdfGenerator: createScanPdf,
          ),
        ),
      ),
    );
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-import')));
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-crop')));
    await waitIo(tester, until: find.text('Adjust page corners'));
    expect(find.text('Adjust page corners'), findsOneWidget);
    expect(find.byKey(const Key('corner-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.byKey(const Key('apply-corners')));
    await waitIo(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape and larger text do not hide correction actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: ScanStudioPage(
            files: files,
            storeFactory: () async => store,
            photoProcessor: (request) async => processPhoto(request),
            scanProcessor: (request) async => processScan(request),
          ),
        ),
      ),
    );
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-import')));
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-crop')));
    await waitIo(tester, until: find.byKey(const Key('apply-corners')));
    expect(find.byKey(const Key('apply-corners')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.byKey(const Key('apply-corners')));
    await waitIo(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'camera and interrupted-capture entry points use real page processing',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final camera = ScanCamera(files.imported);
      await tester.pumpWidget(
        screen(camera: camera, recovered: files.imported),
      );
      await waitIo(tester);
      expect(find.byKey(const Key('scan-add-recovered')), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('scan-add-recovered')));
      // The banner disappears only when the recovered page has really been
      // added and saved, so wait for that instead of counting pump rounds.
      await settleUntilGone(
        tester,
        find.byKey(const Key('scan-add-recovered')),
      );
      // The page count is the app's own signal that the draft was loaded; wait
      // for it instead of assuming a fixed number of pumps was enough.
      await settleUntil(tester, find.textContaining('1 of 8 pages'));
      expect(find.textContaining('1 of 8 pages'), findsOneWidget);
      expect(find.byKey(const Key('scan-add-recovered')), findsNothing);
      await tapVisible(tester, find.byKey(const Key('scan-camera')));
      await waitIo(tester);
      // The page count is the app's own signal that the draft was loaded; wait
      // for it instead of assuming a fixed number of pumps was enough.
      await settleUntil(tester, find.textContaining('2 of 8 pages'));
      expect(find.textContaining('2 of 8 pages'), findsOneWidget);
      expect((await readDraft(tester, store)), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
