import 'dart:typed_data';

import 'package:desksuite/images/photo_processor.dart';
import 'package:desksuite/main.dart';
import 'package:desksuite/printing/photo_sheet.dart';
import 'package:desksuite/printing/print_gateway.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/reveal.dart';

class PhotoFiles implements FileGateway {
  PhotoFiles({Uint8List? source})
    : original =
          source ??
          Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 2)));
  final Uint8List original;
  Uint8List? exported;
  String? exportedName;
  @override
  Future<Uint8List?> pickImage() async => original;
  @override
  Future<Uint8List?> pickProject() async => null;
  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    exportedName = name;
    exported = bytes;
    return true;
  }
}

class PhotoPrinter implements PrintGateway {
  Uint8List? pdf;
  double? widthMm, heightMm;
  @override
  Future<bool> printPdf({
    required Uint8List bytes,
    required String name,
    required double widthMm,
    required double heightMm,
  }) async {
    pdf = bytes;
    this.widthMm = widthMm;
    this.heightMm = heightMm;
    return true;
  }
}

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

Future<void> expectWorkingSize(WidgetTester tester, String value) async {
  final target = find.text(value);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      -250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await reveal(tester, target);
  await tester.pumpAndSettle();
  expect(target, findsOneWidget);
}

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  testWidgets('photo import, rotate, crop, resize and real JPEG export', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = PhotoFiles();
    final untouched = Uint8List.fromList(files.original);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoPage(
            files: files,
            processor: (request) async => processPhoto(request),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('photo-choose')));
    await settleIo(tester);
    expect(find.text('4 × 2 px · working copy'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('photo-rotate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-rotate')));
    await settleIo(tester);
    await expectWorkingSize(tester, '2 × 4 px · working copy');
    await reveal(tester, find.byKey(const Key('photo-crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-crop')));
    await settleIo(tester);
    await expectWorkingSize(tester, '2 × 2 px · working copy');
    await reveal(tester, find.byKey(const Key('photo-resize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-resize')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('photo-width')), '1');
    await tester.tap(find.widgetWithText(FilledButton, 'Resize'));
    await settleIo(tester);
    await expectWorkingSize(tester, '1 × 1 px · working copy');
    await reveal(tester, find.byKey(const Key('photo-jpg')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-jpg')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Export JPG').last);
    await settleIo(tester);
    expect(find.text('Review JPEG output'), findsOneWidget);
    expect(find.textContaining('bytes'), findsWidgets);
    await tester.tap(find.byKey(const Key('photo-save-copy')));
    await settleIo(tester);
    expect(files.exportedName, 'desksuite-photo.jpg');
    expect(files.exported!.take(2), [0xff, 0xd8]);
    expect(files.original, orderedEquals(untouched));
    expect(tester.takeException(), isNull);
  });
  testWidgets('exact dimensions require an explicit aspect-ratio choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = PhotoFiles();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoPage(
            files: files,
            processor: (request) async => processPhoto(request),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('photo-choose')));
    await settleIo(tester);
    await reveal(tester, find.byKey(const Key('photo-resize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-resize')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep aspect ratio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('photo-width')), '3');
    await tester.enterText(find.byKey(const Key('photo-height')), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Resize'));
    await settleIo(tester);
    await expectWorkingSize(tester, '3 × 3 px · working copy');
    await reveal(tester, find.byKey(const Key('photo-png')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-png')));
    await settleIo(tester);
    expect(find.text('Review PNG output'), findsOneWidget);
    await tester.tap(find.byKey(const Key('photo-save-copy')));
    await settleIo(tester);
    final decoded = img.decodePng(files.exported!)!;
    expect([decoded.width, decoded.height], [3, 3]);
    expect(
      files.original,
      orderedEquals(
        Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 2))),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('print-size resize ignores invalid hidden pixel fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <PhotoRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoPage(
            files: PhotoFiles(),
            processor: (request) async {
              requests.add(request);
              return processPhoto(request);
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('photo-choose')));
    await settleIo(tester);
    await reveal(tester, find.byKey(const Key('photo-resize')));
    await tester.tap(find.byKey(const Key('photo-resize')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('photo-width')), '');
    await tester.tap(find.byKey(const Key('photo-resize-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print size').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('photo-print-width-mm')), '1');
    await reveal(tester, find.byKey(const Key('photo-print-dpi')));
    await tester.enterText(find.byKey(const Key('photo-print-dpi')), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Resize'));
    await settleIo(tester);
    final request = requests.lastWhere(
      (item) => item.action == PhotoAction.resize,
    );
    expect([request.width, request.height], [4, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optimizer previews and saves an A4 PDF copy', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = PhotoFiles();
    final source = Uint8List.fromList(files.original);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoPage(
            files: files,
            processor: (request) async => processPhoto(request),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('photo-choose')));
    await settleIo(tester);
    await reveal(tester, find.byKey(const Key('photo-optimizer')));
    await tester.tap(find.byKey(const Key('photo-optimizer')));
    await tester.pumpAndSettle();
    final picker = find.byKey(const Key('optimizer-export-format'));
    await reveal(tester, picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A4 image PDF (not encrypted)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Optimise & preview'));
    await settleUntil(tester, find.text('Review optimised export'));
    expect(
      find.textContaining('One image is fitted on A4 with 10 mm margins'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('photo-optimizer-save')));
    await settleIo(tester);
    expect(files.exportedName, 'desksuite-optimized.pdf');
    expect(String.fromCharCodes(files.exported!.take(5)), '%PDF-');
    expect(files.original, orderedEquals(source));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'photo sheet validates capacity, exports a PDF and sends a print job',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final files = PhotoFiles();
      final printer = PhotoPrinter();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoPage(
              files: files,
              processor: (request) async => processPhoto(request),
              printer: printer,
              sheetGenerator: generatePhotoSheet,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('photo-choose')));
      await settleIo(tester);
      await reveal(tester, find.byKey(const Key('photo-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-sheet')));
      await tester.pumpAndSettle();
      final copies = find.byKey(const Key('sheet-copies'));
      await reveal(tester, copies);
      await tester.pumpAndSettle();
      await tester.enterText(copies, '26');
      await tester.pump();
      expect(find.textContaining('Only 4 photo(s) fit'), findsOneWidget);
      final export = find.widgetWithText(OutlinedButton, 'Export PDF');
      expect(tester.widget<OutlinedButton>(export).onPressed, isNull);
      await tester.enterText(copies, '4');
      await tester.pumpAndSettle();
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(find.text('Low-resolution photo'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await settleIo(tester);
      expect(files.exportedName, 'desksuite-photo-sheet.pdf');
      expect(String.fromCharCodes(files.exported!.take(5)), '%PDF-');
      await reveal(tester, find.byKey(const Key('photo-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Print'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await settleIo(tester);
      expect(printer.widthMm, 101.6);
      expect(printer.heightMm, 152.4);
      expect(String.fromCharCodes(printer.pdf!.take(5)), '%PDF-');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'solid background action composites transparent pixels and exports',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transparent = img.Image(width: 2, height: 1, numChannels: 4);
      transparent.setPixelRgba(0, 0, 255, 0, 0, 0);
      transparent.setPixelRgba(1, 0, 255, 0, 0, 255);
      final files = PhotoFiles(
        source: Uint8List.fromList(img.encodePng(transparent)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoPage(
              files: files,
              processor: (request) async => processPhoto(request),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('photo-choose')));
      await settleIo(tester);
      await reveal(tester, find.byKey(const Key('photo-background')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-background')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pale blue'));
      await settleIo(tester);
      await reveal(tester, find.byKey(const Key('photo-png')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-png')));
      await settleIo(tester);
      await tester.tap(find.byKey(const Key('photo-save-copy')));
      await settleIo(tester);

      final output = img.decodePng(files.exported!)!;
      expect([output.width, output.height], [2, 1]);
      expect(output.getPixel(0, 0).r, closeTo(220, 1));
      expect(output.getPixel(0, 0).g, closeTo(235, 1));
      expect(output.getPixel(0, 0).b, closeTo(250, 1));
      expect(output.getPixel(1, 0).r, 255);
      expect(output.getPixel(1, 0).g, 0);
      expect(output.getPixel(1, 0).b, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
