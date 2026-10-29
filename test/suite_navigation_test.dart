import 'dart:convert';
import 'dart:io';

import 'package:desksuite/app/section_artwork.dart';
import 'package:desksuite/app/theme.dart';
import 'package:desksuite/main.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/workspace/creative_studio_page.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
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

Future<void> removeTemporaryDirectory(Directory directory) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 4) rethrow;
      // Windows can briefly hold a handle after an asynchronous project read.
      await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
    }
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
  testWidgets('home tool cards open the real local workflows', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('desksuite-shortcuts-'),
    ))!;
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => '${temp.path}/support',
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final root = Directory('${temp.path}/projects');
    await tester.runAsync(() async {
      await root.create(recursive: true);
      await File('${root.path}/welcome.json')
          .writeAsString('{"version":1,"seen":true}');
    });
    final repo = ProjectRepository(root);
    await tester.pumpWidget(
      DeskSuiteApp(
        showStartupAnimation: false,
        repository: repo,
        fileGateway: NoFiles(),
      ),
    );
    await settleIo(tester);
    expect(find.byType(BrandMark), findsWidgets);
    expect(find.byType(WorkspaceToolCard), findsNWidgets(7));
    final scanTile = tester.getRect(find.byKey(const Key('home-open-scan')));
    final pdfTile = tester.getRect(find.byKey(const Key('home-open-pdf')));
    expect(scanTile.top, pdfTile.top, reason: 'phone shortcuts fit two across');
    expect(scanTile.bottom, pdfTile.bottom, reason: 'neighboring cards align');
    expect(scanTile.right, lessThan(pdfTile.left));
    expect(pdfTile.right, lessThanOrEqualTo(360));
    final photoTile = tester.getRect(find.byKey(const Key('home-open-photo')));
    final textTile = tester.getRect(find.byKey(const Key('home-open-text')));
    expect(photoTile.top, textTile.top);
    expect(photoTile.bottom, textTile.bottom);
    final search = find.byKey(const Key('home-shortcut-search'));
    await reveal(tester, search);
    await tester.enterText(search, 'PHOTO');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-open-photo')), findsOneWidget);
    expect(find.byKey(const Key('home-open-scan')), findsNothing);
    expect(find.text('1 of 7 shortcuts'), findsOneWidget);
    await tester.enterText(search, 'not-a-real-shortcut');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-shortcut-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-clear-shortcut-search')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceToolCard), findsNWidgets(7));
    final routes = <String, (String, WorkspaceSection, String)>{
      'home-open-scan': (
        'scan-import',
        WorkspaceSection.scans,
        SectionArt.scan,
      ),
      'home-open-photo': (
        'photo-choose',
        WorkspaceSection.photos,
        SectionArt.photo,
      ),
      'home-open-text': ('ocr-choose', WorkspaceSection.text, SectionArt.text),
      'home-open-converter': (
        'office-choose',
        WorkspaceSection.office,
        SectionArt.office,
      ),
      'home-open-design': (
        'new-design',
        WorkspaceSection.design,
        SectionArt.design,
      ),
      'home-open-projects': (
        'workspace-page-projects',
        WorkspaceSection.projects,
        SectionArt.projects,
      ),
    };
    var first = true;
    for (final route in routes.entries) {
      if (!first) await navigate(tester, 'Home');
      first = false;
      final (targetKey, section, expectedArt) = route.value;
      final shortcut = find.byKey(Key(route.key));
      await reveal(tester, shortcut);
      expect(tester.widget<WorkspaceToolCard>(shortcut).section, section);
      final cardArt = find.descendant(
        of: shortcut,
        matching: find.byType(SectionArtwork),
      );
      expect(tester.widget<SectionArtwork>(cardArt).asset, expectedArt);
      await tester.tap(shortcut);
      await settleUntil(tester, find.byKey(Key(targetKey)));
      expect(
        find.byKey(ValueKey('workspace-page-${section.name}')),
        findsOneWidget,
      );
      final headerArt = find.byKey(
        ValueKey('section-header-art-${section.name}'),
      );
      expect(headerArt, findsOneWidget);
      expect(tester.widget<SectionArtwork>(headerArt).asset, expectedArt);
      if (section == WorkspaceSection.photos) {
        final sample = find.byKey(const Key('photo-example'));
        await reveal(tester, sample);
        await tester.tap(sample);
        await settleUntil(tester, find.byKey(const Key('photo-zoom')));
      }
      expect(tester.takeException(), isNull, reason: route.key);
    }
    // PDF uses an honest standard icon rather than a new launcher logo.
    await navigate(tester, 'Home');
    final pdfShortcut = find.byKey(const Key('home-open-pdf'));
    await reveal(tester, pdfShortcut);
    expect(
      tester.widget<WorkspaceToolCard>(pdfShortcut).section,
      WorkspaceSection.pdfStudio,
    );
    expect(
      find.descendant(of: pdfShortcut, matching: find.byType(SectionArtwork)),
      findsNothing,
    );
    await tester.tap(pdfShortcut);
    await settleUntil(tester, find.byKey(const Key('pdf-studio-open')));
    expect(
      find.byKey(const ValueKey('workspace-page-pdfStudio')),
      findsOneWidget,
    );
    // Switching sections should not recreate a visited page and lose its work.
    await navigate(tester, 'Photo Studio');
    expect(find.byKey(const Key('photo-zoom')), findsOneWidget);
    expect(find.byKey(const Key('photo-example')), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
      addTearDown(() => removeTemporaryDirectory(temp));
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
      await tester.pumpWidget(
        DeskSuiteApp(showStartupAnimation: false, fileGateway: NoFiles()),
      );
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
      // Importing an earlier project writes a new local copy before opening
      // the editor; wait for that real transition rather than a fixed delay.
      final canvas = find.byKey(const Key('design-canvas'));
      await settleUntil(tester, canvas);
      expect(canvas, findsOneWidget);
      final back = find.byTooltip('Back to workspace');
      await settleUntilEnabled(tester, back);
      await settleUntil(tester, back.hitTestable());
      await tester.tap(back.hitTestable());
      await settleUntilGone(tester, canvas);
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
      await settleUntil(tester, find.text('Existing poster'));
      expect(find.text('Existing poster'), findsOneWidget);
      await tester.tap(find.text('Existing poster'));
      await settleUntil(tester, canvas);
      expect(canvas, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
