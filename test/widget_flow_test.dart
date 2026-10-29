import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/main.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFiles implements FileGateway {
  final Uint8List image = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAMCAIAAADkharWAAAAF0lEQVR4nGPs2VLBQApgIkn1qIYRpAEADVwB0JlVGsIAAAAASUVORK5CYII=',
  );
  Uint8List? exported;
  String? exportedName;
  @override
  Future<Uint8List?> pickImage() async => image;
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

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets('phone workspace creates, edits, exports and reopens a design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('desksuite_widget_'),
    ))!;
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final repo = ProjectRepository(dir);
    final files = FakeFiles();
    await tester.pumpWidget(
      DeskSuiteApp(
        showStartupAnimation: false,
        repository: repo,
        fileGateway: files,
      ),
    );
    await settleIo(tester);
    // The premium workbench is task-first; create a design from its
    // primary action rather than the retired generic landing screen.
    expect(find.byKey(const Key('home-open-scan')), findsOneWidget);
    expect(find.byKey(const Key('home-open-design')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('home-open-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-open-design')));
    // The primary action opens Creative Studio. Wait for its local project
    // list to initialize, then invoke the explicit New design action.
    await settleIo(tester);
    expect(find.byKey(const Key('new-design')), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-design')));
    // The workspace contains an ongoing animation; pump the dialog directly
    // rather than waiting for every ticker in the entire app to become idle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('project-name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('project-name')),
      'Studio poster',
    );
    await tester.tap(find.byKey(const Key('create-design')));
    await settleIo(tester);
    expect(find.byKey(const Key('design-canvas')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-text')));
    await tester.pump();
    expect(find.textContaining('TEXT SELECTED'), findsOneWidget);
    await tester.tap(find.text('Edit object'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit text'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('edit-text-field')),
      'Printed locally',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shape'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rectangle'));
    await tester.pumpAndSettle();
    final canvas = tester.getRect(find.byKey(const Key('design-canvas')));
    final drag = await tester.startGesture(
      Offset(canvas.left + canvas.width * .2, canvas.top + canvas.height * .22),
    );
    await tester.pump();
    await drag.moveBy(const Offset(25, 20));
    await tester.pump();
    await drag.moveBy(const Offset(20, 15));
    await tester.pump();
    await drag.moveBy(const Offset(10, 8));
    await tester.pump();
    await drag.up();
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-image')));
    await settleIo(tester);
    expect(find.textContaining('IMAGE SELECTED'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    await tester.tap(find.byTooltip('Export design'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print-ready PDF · 150 dpi'));
    await settleIo(tester);
    expect(find.text('Low-resolution image'), findsOneWidget);
    await tester.tap(find.text('Export anyway'));
    for (var i = 0; i < 150 && files.exported == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(
      files.exportedName,
      'Studio poster.pdf',
      reason: 'Export should complete without error',
    );
    expect(latin1.decode(files.exported!.sublist(0, 5)), '%PDF-');
    final backButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Back to workspace',
    );
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (tester.widget<IconButton>(backButton).onPressed != null) break;
    }
    expect(tester.widget<IconButton>(backButton).onPressed, isNotNull);
    await tester.tap(find.byTooltip('Back to workspace'));
    await settleIo(tester);
    for (
      var i = 0;
      i < 150 && find.text('Studio poster').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(find.text('Studio poster'), findsOneWidget);
    final projects = await tester.runAsync(() => repo.list());
    expect(projects!.projects.length, 1);
    final doc = await tester.runAsync(
      () => repo.load(projects.projects.single.id),
    );
    expect(doc!.elements.length, 3);
    expect(doc.elements.first.text, 'Printed locally');
    expect(doc.elements[1].x, greaterThan(210 * .15));
    expect(doc.elements.last.imageBytes, orderedEquals(files.image));
    await tester.ensureVisible(find.text('Studio poster'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Studio poster'));
    await settleIo(tester);
    expect(find.byKey(const Key('design-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
