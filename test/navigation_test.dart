import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/main.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter/material.dart';
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
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets(
    'small phone navigation labels planned studios and persists theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('desksuite_nav_'),
      ))!;
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final repo = ProjectRepository(dir);
      await tester.pumpWidget(
        DeskSuiteApp(
          showStartupAnimation: false,
          repository: repo,
          fileGateway: NoFiles(),
        ),
      );
      await settleIo(tester);
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      expect(find.text('Photo Studio'), findsOneWidget);
      // Planned studios are listed below available tools in the drawer list.
      final drawer = find.byType(Drawer);
      await reveal(tester, find.text('PLANNED'), within: drawer);
      expect(find.text('PLANNED'), findsWidgets);
      await reveal(tester, find.text('Settings'), within: drawer);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Dark appearance'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await settleIo(tester);
      expect(await tester.runAsync(() => repo.readDarkMode()), isTrue);
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Files & Projects'));
      await tester.pumpAndSettle();
      expect(find.text('A fresh start'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
