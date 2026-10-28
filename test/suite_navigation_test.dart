import 'dart:convert';
import 'dart:io';

import 'package:desksuite/main.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/workspace/creative_studio_page.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

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
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

Future<void> navigate(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Open navigation'));
  await tester.pumpAndSettle();
  final item = find.descendant(
    of: find.byType(Drawer),
    matching: find.text(label),
  );
  final drawerScroll = find
      .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
      .first;
  // The expanded navigation can extend beyond a compact phone's viewport.
  await tester.drag(drawerScroll, const Offset(0, 1200));
  await tester.pumpAndSettle();
  if (item.evaluate().isEmpty) {
    await tester.scrollUntilVisible(item, 250, scrollable: drawerScroll);
  }
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await settleIo(tester);
}

void main() {
  testWidgets(
    'main workspace opens live studios and imports an earlier project into its existing documents root',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('desksuite_unified_'),
      ))!;
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final documents = Directory('${temp.path}/documents/DeskSuite');
      final legacyRoot = Directory('${temp.path}/support/desksuite');
      final oldFolder = Directory('${legacyRoot.path}/projects');
      await tester.runAsync(() => oldFolder.create(recursive: true));
      final oldFile = File('${oldFolder.path}/123.dsproject');
      final original = jsonEncode({
        'schemaVersion': 1,
        'id': '123',
        'name': 'Existing poster',
        'width': 360.0,
        'height': 480.0,
        'updated': '2026-10-27T12:30:00Z',
        'items': [
          {
            'id': 'one',
            'kind': 'text',
            'text': 'Earlier content',
            'x': 10,
            'y': 20,
            'w': 100,
            'h': 50,
            'color': 0xff292b29,
            'size': 24,
          },
        ],
      });
      await tester.runAsync(() => oldFile.writeAsString(original));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'getApplicationDocumentsDirectory'
            ? '${temp.path}/documents'
            : '${temp.path}/support',
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final repo = ProjectRepository(documents, legacyRoot: legacyRoot);
      final existing = DesignDocument.blank(
        name: 'Existing main design',
        widthMm: 210,
        heightMm: 297,
      );
      await tester.runAsync(() => repo.save(existing));
      await tester.pumpWidget(DeskSuiteApp(fileGateway: NoFiles()));
      await settleIo(tester);
      await navigate(tester, 'Creative Studio');
      final legacy = find.byKey(const ValueKey('legacy-123'));
      final creativeScroll = find.descendant(
        of: find.byType(CreativeStudioPage),
        matching: find.byType(Scrollable),
      );
      await settleUntil(tester, creativeScroll);
      await tester.scrollUntilVisible(
        legacy,
        250,
        scrollable: creativeScroll.first,
      );
      await tester.ensureVisible(legacy);
      await tester.pumpAndSettle();
      await tester.tap(legacy);
      await settleIo(tester);
      expect(find.byKey(const Key('design-canvas')), findsOneWidget);
      await tester.tap(find.byTooltip('Back to workspace'));
      await settleIo(tester);
      expect(await tester.runAsync(() => oldFile.readAsString()), original);
      final converted = await tester.runAsync(() => repo.list());
      expect(converted!.projects, hasLength(2));
      expect(
        converted.projects.map((p) => p.name),
        contains('Existing main design'),
      );
      expect(
        await tester.runAsync(
          () => Directory('${documents.path}/projects').exists(),
        ),
        isTrue,
      );
      for (final label in [
        'Photo Studio',
        'Office Notes',
        'Print Studio',
        'Business & POS',
      ]) {
        await navigate(tester, label);
        expect(find.text(label), findsWidgets);
        expect(tester.takeException(), isNull, reason: label);
      }
      await navigate(tester, 'Conversion routes');
      final photoRoute = find.byKey(const Key('conversion-photos'));
      await tester.ensureVisible(photoRoute);
      await tester.pumpAndSettle();
      await tester.tap(photoRoute);
      await settleIo(tester);
      expect(find.text('Photo Studio'), findsWidgets);
      expect(find.byKey(const Key('photo-choose')), findsOneWidget);
      await navigate(tester, 'Files & Projects');
      for (
        var i = 0;
        i < 100 && find.text('Existing poster').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(find.text('Existing poster'), findsOneWidget);
      await tester.tap(find.text('Existing poster'));
      await settleIo(tester);
      expect(find.byKey(const Key('design-canvas')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
