import 'dart:convert';
import 'dart:typed_data';

import 'package:desksuite/office/office_convert_page.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/office_fixtures.dart';
import 'support/reveal.dart';

class PickerDouble implements DocumentPicker {
  PickerDouble(this.document);
  PickedDocument? document;
  @override
  Future<PickedDocument?> pickDocument() async => document;
}

class FilesDouble implements FileGateway {
  String? savedName;
  String? savedMime;
  Uint8List? savedBytes;
  bool cancel = false;
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
    savedMime = mimeType;
    savedBytes = bytes;
    return !cancel;
  }
}

Widget host({
  required DocumentPicker picker,
  required FilesDouble files,
}) => MaterialApp(
  home: Scaffold(
    body: OfficeConvertPage(picker: picker, files: files),
  ),
);

/// Allows a real isolate-backed conversion to finish under the test clock.
Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pump();
}

void main() {
  testWidgets('detects a DOCX, converts to PDF and saves the output', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final files = FilesDouble();
    final picker = PickerDouble((bytes: docxFixture(), name: 'invoice.docx'));
    await tester.pumpWidget(host(picker: picker, files: files));
    await reveal(tester, find.byKey(const Key('office-choose')));
    await tester.tap(find.byKey(const Key('office-choose')));
    await settleIo(tester);

    expect(find.textContaining('DOCX'), findsWidgets);
    expect(find.textContaining('ZIP package'), findsOneWidget);
    // Only real routes are offered.
    expect(find.byKey(const Key('office-route-DOCX→PDF')), findsOneWidget);
    expect(find.byKey(const Key('office-route-DOCX→TXT')), findsOneWidget);
    expect(find.byKey(const Key('office-route-DOCX→XLSX')), findsNothing);

    await reveal(tester, find.byKey(const Key('office-convert')));
    await tester.tap(find.byKey(const Key('office-convert')));
    await settleIo(tester);

    await reveal(tester, find.byKey(const Key('office-save')));
    expect(find.text('invoice.pdf'), findsOneWidget);
    await tester.tap(find.byKey(const Key('office-save')));
    await tester.pumpAndSettle();

    expect(files.savedName, 'invoice.pdf');
    expect(files.savedMime, 'application/pdf');
    expect(latin1.decode(files.savedBytes!.sublist(0, 5)), '%PDF-');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'states when no route can run instead of offering a dead button',
    (tester) async {
      tester.view.physicalSize = const Size(430, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A legacy binary .doc cannot be read without an external engine.
      await tester.pumpWidget(
        host(
          picker: PickerDouble((bytes: legacyOleFixture(), name: 'old.doc')),
          files: FilesDouble(),
        ),
      );
      await reveal(tester, find.byKey(const Key('office-choose')));
      await tester.tap(find.byKey(const Key('office-choose')));
      await settleIo(tester);

      expect(find.textContaining('No conversion is available'), findsOneWidget);
      expect(find.byKey(const Key('office-convert')), findsNothing);
    },
  );

  testWidgets('reports an unrecognised file with an actionable message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        picker: PickerDouble((
          bytes: Uint8List.fromList([0x00, 0x01, 0x02, 0x03]),
          name: 'mystery.bin',
        )),
        files: FilesDouble(),
      ),
    );
    await reveal(tester, find.byKey(const Key('office-choose')));
    await tester.tap(find.byKey(const Key('office-choose')));
    await settleIo(tester);
    expect(find.textContaining('not a supported document'), findsOneWidget);
  });


}
