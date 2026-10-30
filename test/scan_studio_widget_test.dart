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
import 'package:flutter/services.dart' show MethodChannel;
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

class ScanCamera implements CameraGateway, CommittedCaptureGateway {
  ScanCamera(this.bytes, {this.discardSucceeds = true});
  final Uint8List bytes;
  bool discardSucceeds;
  int acknowledgements = 0;
  int discardAttempts = 0;
  @override
  Future<void> acknowledgeCaptureSaved() async {
    acknowledgements++;
  }

  @override
  Future<bool> discardPendingCapture() async {
    discardAttempts++;
    return discardSucceeds;
  }

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

/// Waits for the real draft read while continuing to pump the test zone.
///
/// A queued write can depend on fake-async microtasks; awaiting its read inside
/// runAsync deadlocks that queue. Start one read in the test zone, then pump
/// and yield to the real I/O/isolate event loop until it completes or times out.
Future<List<ScanDraftPage>> readDraft(
  WidgetTester tester,
  ScanDraftStore store,
) async {
  List<ScanDraftPage>? pages;
  Object? error;
  StackTrace? trace;
  var complete = false;
  store.load().then<void>(
    (value) {
      pages = value;
      complete = true;
    },
    onError: (Object failure, StackTrace stack) {
      error = failure;
      trace = stack;
      complete = true;
    },
  );
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!complete && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  if (!complete) {
    fail('The scan draft could not be read back within 30 seconds.');
  }
  if (error != null) Error.throwWithStackTrace(error!, trace!);
  return pages!;
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
    if (!await temp.exists()) return;
    // Windows may briefly retain a file handle after async image/PDF work.
    // Retry transient directory deletion failures rather than failing an
    // otherwise-passing widget test during teardown.
    FileSystemException? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
        return;
      } on FileSystemException catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }
    if (Platform.isWindows) {
      // Temporary test data is outside the repository; a lingering Windows
      // handle must not mask the actual test result.
      return;
    }
    if (lastError != null) throw lastError;
  });

  Widget screen({
    CameraGateway? camera,
    Uint8List? recovered,
    bool isActive = true,
    Future<ScanCorners?> Function(PhotoResult)? cornerSuggester,
    Widget Function(Uint8List)? textExtractionBuilder,
  }) => MaterialApp(
    home: Scaffold(
      body: ScanStudioPage(
        files: files,
        camera: camera,
        isActive: isActive,
        recoveredCapture: recovered,
        cornerSuggester: cornerSuggester,
        storeFactory: () async => store,
        photoProcessor: (request) async => processPhoto(request),
        scanProcessor: (request) async => processScan(request),
        cleanupProcessor: (request) async => processDocumentCleanup(request),
        pdfGenerator: createScanPdf,
        textExtractionBuilder: textExtractionBuilder,
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
    'sends the selected working page to text extraction without changing the draft',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uint8List? sent;
      await tester.pumpWidget(
        screen(
          textExtractionBuilder: (bytes) {
            sent = Uint8List.fromList(bytes);
            return const Center(child: Text('Selected scan page for OCR'));
          },
        ),
      );
      await waitIo(tester);
      await tapVisible(tester, find.byKey(const Key('scan-import')));
      await waitIo(tester);
      await settleUntil(tester, find.textContaining('1 of 8 pages'));
      await tapVisible(tester, find.byKey(const Key('scan-rotate')));
      await waitIo(tester);
      final before = (await readDraft(tester, store)).single.image;
      await tapVisible(tester, find.byKey(const Key('scan-extract-text')));
      await tester.pumpAndSettle();
      expect(find.text('Selected scan page for OCR'), findsOneWidget);
      expect(sent, orderedEquals(before.bytes));
      await tester.pageBack();
      await tester.pumpAndSettle();
      final after = (await readDraft(tester, store)).single.image;
      expect(after.bytes, orderedEquals(before.bytes));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed camera deletion keeps the recoverable image', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = Uint8List.fromList(files.imported);
    final camera = ScanCamera(original, discardSucceeds: false);
    await tester.pumpWidget(screen(camera: camera, recovered: original));
    await settleUntil(tester, find.byKey(const Key('scan-add-recovered')));

    Future<void> confirmDismissal() async {
      await tapVisible(tester, find.text('Dismiss'));
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Dismiss'),
      );
      await tapVisible(tester, confirm);
    }

    await confirmDismissal();
    await settleUntil(tester, find.textContaining('private camera copy'));
    expect(camera.discardAttempts, 1);
    expect(find.byKey(const Key('scan-add-recovered')), findsOneWidget);
    await tapVisible(tester, find.text('Export recovered original'));
    await waitIo(tester);
    expect(files.exported, orderedEquals(original));
    expect(camera.acknowledgements, 0);

    camera.discardSucceeds = true;
    await confirmDismissal();
    await settleUntilGone(tester, find.byKey(const Key('scan-add-recovered')));
    expect(camera.discardAttempts, 2);
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
    final camera = ScanCamera(files.imported);
    await tester.pumpWidget(screen(camera: camera));
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-camera')));
    await settleUntil(
      tester,
      find.textContaining('camera image is in the unsaved draft'),
    );
    // The save-error card sits below the recovery card on a compact screen.
    // Scroll it into the lazy ListView before waiting for the failed write.
    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pump();
    await settleUntil(tester, find.textContaining('Draft could not be saved'));
    expect(find.textContaining('Draft could not be saved'), findsOneWidget);
    // The recovery details remain reachable rather than clipped.
    await tester.drag(find.byType(ListView).first, const Offset(0, 520));
    await tester.pump();
    expect(
      find.textContaining('camera image is in the unsaved draft'),
      findsOneWidget,
    );
    expect((await readDraft(tester, store)), isEmpty);
    expect(camera.acknowledgements, 0);
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
    expect(camera.acknowledgements, 1);
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

  testWidgets('native capture commits before showing assisted corner review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cache = Directory('${temp.path}/cache');
    await tester.runAsync(() => cache.create());
    final capture = File('${cache.path}/desksuite-capture-review-123.jpg');
    final jpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 80, height: 60)),
    );
    await tester.runAsync(() => capture.writeAsBytes(jpeg));
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const cameraChannel = MethodChannel('com.zamcan.desksuite/document_camera');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (call) async => cache.path);
    messenger.setMockMethodCallHandler(
      cameraChannel,
      (call) async => capture.path,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));
    addTearDown(() => messenger.setMockMethodCallHandler(cameraChannel, null));
    var suggestions = 0;
    await tester.pumpWidget(
      screen(
        camera: AndroidCameraGateway(),
        cornerSuggester: (_) async {
          suggestions++;
          return const ScanCorners.full();
        },
      ),
    );
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-camera')));
    await waitIo(tester, until: find.text('Adjust page corners'));
    expect(find.text('Adjust page corners'), findsOneWidget);
    await tester.pump();
    expect(suggestions, 1);
    expect(await tester.runAsync(capture.exists), isFalse);
    expect((await readDraft(tester, store)), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('finished capture does not open a review over another section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cache = Directory('${temp.path}/cache');
    await tester.runAsync(() => cache.create());
    final capture = File('${cache.path}/desksuite-capture-inactive-123.jpg');
    final jpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 80, height: 60)),
    );
    await tester.runAsync(() => capture.writeAsBytes(jpeg));
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const cameraChannel = MethodChannel('com.zamcan.desksuite/document_camera');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (call) async => cache.path);
    messenger.setMockMethodCallHandler(
      cameraChannel,
      (call) async => capture.path,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));
    addTearDown(() => messenger.setMockMethodCallHandler(cameraChannel, null));
    await tester.pumpWidget(
      screen(camera: AndroidCameraGateway(), isActive: false),
    );
    await waitIo(tester);
    await tapVisible(tester, find.byKey(const Key('scan-camera')));
    await settleUntil(tester, find.textContaining('1 of 8 pages'));
    expect(find.text('Adjust page corners'), findsNothing);
    expect((await readDraft(tester, store)), hasLength(1));
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
