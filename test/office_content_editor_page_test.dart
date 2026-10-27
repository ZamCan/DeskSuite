import 'dart:typed_data';

import 'package:desksuite/office/office_content_editor_page.dart';
import 'package:desksuite/office/office_reader.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/office_fixtures.dart';
import 'support/reveal.dart';

class EditorFiles implements FileGateway {
  String? savedName;
  String? savedMime;
  Uint8List? savedBytes;

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
    savedBytes = Uint8List.fromList(bytes);
    return true;
  }
}

void main() {
  testWidgets('edits real DOCX content and exports a new DOCX package', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = docxFixture();
    final original = Uint8List.fromList(source);
    final files = EditorFiles();
    await tester.pumpWidget(
      MaterialApp(
        home: OfficeContentEditorPage(
          source: source,
          sourceName: 'invoice.docx',
          files: files,
        ),
      ),
    );

    await settleUntil(tester, find.byKey(const Key('office-editor-text-0')));
    await tester.enterText(
      find.byKey(const Key('office-editor-text-0')),
      'Edited by DeskSuite',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('office-editor-export')));
    await tester.pumpAndSettle();

    expect(files.savedName, 'edited-invoice.docx');
    expect(
      files.savedMime,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(files.savedBytes, isNotNull);
    final reopened = readOfficeDocument(
      files.savedBytes!,
      fileName: 'edited-invoice.docx',
    );
    expect(reopened.plainText, contains('Edited by DeskSuite'));
    expect(source, orderedEquals(original));
    expect(tester.takeException(), isNull);
  });
}
