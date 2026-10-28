import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/main.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

class WelcomeFiles implements FileGateway {
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

Future<void> waitIo(WidgetTester tester) async {
  for (var i = 0; i < 35; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets(
    'first-run introduction is skippable, remembered and tutorials remain revisitable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('desksuite-welcome-'),
      ))!;
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final repo = ProjectRepository(Directory('${temp.path}/documents'));
      await tester.pumpWidget(
        DeskSuiteApp(
          showStartupAnimation: false,
          repository: repo,
          fileGateway: WelcomeFiles(),
        ),
      );
      await waitIo(tester);
      expect(find.byKey(const Key('welcome-introduction')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('welcome-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('welcome-skip')));
      await waitIo(tester);
      expect(await tester.runAsync(repo.readWelcomeSeen), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        DeskSuiteApp(
          showStartupAnimation: false,
          repository: repo,
          fileGateway: WelcomeFiles(),
        ),
      );
      await waitIo(tester);
      expect(find.byKey(const Key('welcome-introduction')), findsNothing);
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Getting started'),
        ),
      );
      await waitIo(tester);
      expect(find.text('Getting started'), findsWidgets);
      // The guide is a lazy list; the new text-extraction and converter cards
      // sit above the cleanup card.
      await reveal(tester, find.text('Clean a shadowed page'));
      expect(find.text('Clean a shadowed page'), findsOneWidget);
      await reveal(tester, find.text('Extract text from a scan'));
      expect(find.text('Extract text from a scan'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Make a multipage image PDF'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Make a multipage image PDF'), findsOneWidget);
      final button = find.widgetWithText(
        OutlinedButton,
        'Open editable example',
      );
      await tester.scrollUntilVisible(
        button,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await waitIo(tester);
      expect(find.byKey(const Key('design-canvas')), findsOneWidget);
      final list = await tester.runAsync(repo.list);
      expect(
        list!.projects.map((p) => p.name),
        contains('Example editable letter'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
