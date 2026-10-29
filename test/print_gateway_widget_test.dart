import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/design/editor_screen.dart';
import 'package:desksuite/main.dart';
import 'package:desksuite/printing/print_gateway.dart';
import 'package:desksuite/printing/print_job.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePrinter implements PrintGateway {
  Uint8List? bytes;
  double? widthMm, heightMm;
  @override
  Future<bool> printPdf({
    required Uint8List bytes,
    required String name,
    required double widthMm,
    required double heightMm,
  }) async {
    this.bytes = bytes;
    this.widthMm = widthMm;
    this.heightMm = heightMm;
    return true;
  }
}

class NoFiles implements FileGateway {
  @override
  Future<Uint8List?> pickImage() async => null;
  @override
  Future<Uint8List?> pickProject() async => null;
  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async => false;
}

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets(
    'A4 print check sends a real PDF with physical dimensions to the adapter',
    (tester) async {
      final printer = FakePrinter();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PrintPage(printer: printer)),
        ),
      );
      await tester.tap(find.text('Preview / print A4'));
      await settleIo(tester);
      expect(latin1.decode(printer.bytes!.take(5).toList()), '%PDF-');
      expect([printer.widthMm, printer.heightMm], [210, 297]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'design print action passes a correctly sized PDF to the adapter',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('desksuite_print_'),
      ))!;
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final repo = ProjectRepository(dir);
      final document = DesignDocument.blank(
        name: 'One inch',
        widthMm: 25.4,
        heightMm: 25.4,
      );
      await tester.runAsync(() => repo.save(document));
      final printer = FakePrinter();
      await tester.pumpWidget(
        MaterialApp(
          home: EditorScreen(
            document: document,
            repository: repo,
            files: NoFiles(),
            printer: printer,
          ),
        ),
      );
      await settleIo(tester);
      await tester.tap(find.byTooltip('Export design'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Print using system dialog · 150 dpi'));
      await settleIo(tester);
      expect(printer.bytes, isNotNull);
      expect([printer.widthMm, printer.heightMm], [25.4, 25.4]);
      final text = latin1.decode(printer.bytes!, allowInvalid: true);
      expect(
        text,
        matches(
          RegExp(
            r'/MediaBox\s*\[\s*0(?:\.0+)?\s+0(?:\.0+)?\s+72(?:\.0+)?\s+72(?:\.0+)?\s*\]',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('prepared print job forwards the intended physical media dimensions', () async {
    final printer = FakePrinter();
    final target = PrintMediaTarget(
      id: 'custom-100x150',
      label: '100 × 150 mm',
      widthMm: 100,
      heightMm: 150,
    );
    final bytes = Uint8List.fromList([37, 80, 68, 70, 45]);
    final job = PrintJob(
      media: target,
      sourceWidthMm: 50,
      sourceHeightMm: 75,
    );

    await printer.printPreparedJob(bytes: bytes, name: 'test.pdf', job: job);

    expect(printer.bytes, bytes);
    expect(printer.widthMm, 100);
    expect(printer.heightMm, 150);
  });

  test('prepared print job refuses invalid geometry before dispatch', () async {
    final printer = FakePrinter();
    final job = PrintJob(
      media: const PrintMediaTarget(
        id: 'bad',
        label: 'Invalid',
        widthMm: 0,
        heightMm: 150,
      ),
      sourceWidthMm: 50,
      sourceHeightMm: 75,
    );

    expect(
      () => printer.printPreparedJob(
        bytes: Uint8List.fromList([1]),
        name: 'invalid.pdf',
        job: job,
      ),
      throwsFormatException,
    );
    expect(printer.bytes, isNull);
  });
}
