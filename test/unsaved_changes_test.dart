import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/workspace/creative_studio_page.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

class FailingRepository extends ProjectRepository {
  FailingRepository(super.root);
  bool failWrites = false;
  @override
  Future<void> save(DesignDocument doc) => failWrites
      ? Future<void>.error(
          const FileSystemException('Simulated storage failure'),
        )
      : super.save(doc);
}

class CapturingFiles implements FileGateway {
  Uint8List? saved;
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
    saved = bytes;
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
  testWidgets(
    'save errors protect unsaved changes and permit an editable recovery copy',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('desksuite_save_failure_'),
      ))!;
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final repo = FailingRepository(dir);
      final files = CapturingFiles();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreativeStudioPage(repository: repo, files: files),
          ),
        ),
      );
      await settleIo(tester);
      await tester.tap(find.byKey(const Key('new-design')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-design')));
      await settleIo(tester);
      await settleUntil(tester, find.byKey(const Key('add-text')));
      repo.failWrites = true;
      await tester.tap(find.byKey(const Key('add-text')));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Changes are not saved'),
        findsOneWidget,
        reason: 'Backgrounding flushes without waiting for the debounce timer',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleIo(tester);
      await tester.tap(find.byTooltip('Back to workspace'));
      await settleIo(tester);
      expect(find.text('Changes could not be saved'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Export design'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Editable project copy'));
      await tester.tap(find.text('Editable project copy'));
      await settleIo(tester);
      expect(files.saved, isNotNull);
      expect(DesignDocument.decode(files.saved!).elements.length, 1);
      final list = await tester.runAsync(() => repo.list());
      final saved = await tester.runAsync(
        () => repo.load(list!.projects.single.id),
      );
      expect(saved!.elements, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
