import 'dart:typed_data';

import 'package:desksuite/images/photo_processor.dart';
import 'package:desksuite/main.dart';
import 'package:desksuite/printing/photo_sheet.dart';
import 'package:desksuite/printing/print_gateway.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class PhotoFiles implements FileGateway {
  PhotoFiles()
    : original = Uint8List.fromList(
        img.encodePng(img.Image(width: 4, height: 2)),
      );
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

void main() {
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
    await tester.ensureVisible(find.byKey(const Key('photo-rotate')));
    await tester.tap(find.byKey(const Key('photo-rotate')));
    await settleIo(tester);
    expect(find.text('2 × 4 px · working copy'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('photo-crop')));
    await tester.tap(find.byKey(const Key('photo-crop')));
    await settleIo(tester);
    expect(find.text('2 × 2 px · working copy'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('photo-resize')));
    await tester.tap(find.byKey(const Key('photo-resize')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('photo-width')), '1');
    await tester.tap(find.widgetWithText(FilledButton, 'Resize'));
    await settleIo(tester);
    expect(find.text('1 × 1 px · working copy'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('photo-jpg')));
    await tester.tap(find.byKey(const Key('photo-jpg')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Export JPG').last);
    await settleIo(tester);
    expect(files.exportedName, 'desksuite-photo.jpg');
    expect(files.exported!.take(2), [0xff, 0xd8]);
    expect(files.original, orderedEquals(untouched));
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
      await tester.ensureVisible(find.byKey(const Key('photo-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-sheet')));
      await tester.pumpAndSettle();
      final copies = find.byKey(const Key('sheet-copies'));
      await tester.ensureVisible(copies);
      await tester.pumpAndSettle();
      await tester.enterText(copies, '26');
      await tester.pump();
      expect(find.textContaining('Only 25 photo(s) fit'), findsOneWidget);
      final export = find.widgetWithText(OutlinedButton, 'Export PDF');
      expect(tester.widget<OutlinedButton>(export).onPressed, isNull);
      await tester.enterText(copies, '8');
      await tester.pumpAndSettle();
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(find.text('Low-resolution photo'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await settleIo(tester);
      expect(files.exportedName, 'desksuite-photo-sheet.pdf');
      expect(String.fromCharCodes(files.exported!.take(5)), '%PDF-');
      await tester.ensureVisible(find.byKey(const Key('photo-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Print'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await settleIo(tester);
      expect(printer.widthMm, 210);
      expect(printer.heightMm, 297);
      expect(String.fromCharCodes(printer.pdf!.take(5)), '%PDF-');
      expect(tester.takeException(), isNull);
    },
  );
}
