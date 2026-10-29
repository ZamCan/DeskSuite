import 'dart:io';

import 'package:desksuite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

void main() {
  testWidgets('notes save, recover after a failed write, and reopen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('desksuite_notes_'),
    ))!;
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => temp.path,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotesPage())),
    );
    await settleUntil(tester, find.text('Saved on this device'));
    await tester.enterText(
      find.byKey(const Key('notes-editor')),
      'First saved note',
    );
    await settleUntil(tester, find.text('Saved on this device'));
    final file = File('${temp.path}/desksuite/notes.txt');
    expect(
      await tester.runAsync(() => file.readAsString()),
      'First saved note',
    );
    if (!Platform.isWindows) {
      final directory = file.parent;
      expect(
        (await tester.runAsync(
          () => Process.run('chmod', ['500', directory.path]),
        ))!.exitCode,
        0,
      );
      try {
        await tester.enterText(
          find.byKey(const Key('notes-editor')),
          'Changes after failure',
        );
        await settleUntil(tester, find.text('Retry saving'));
        expect(find.text('Changes are not saved'), findsOneWidget);
        expect(find.text('Retry saving'), findsOneWidget);
        expect(
          await tester.runAsync(() => file.readAsString()),
          'First saved note',
        );
      } finally {
        await tester.runAsync(
          () => Process.run('chmod', ['700', directory.path]),
        );
      }
      await tester.tap(find.text('Retry saving'));
      await settleUntil(tester, find.text('Saved on this device'));
      expect(
        await tester.runAsync(() => file.readAsString()),
        'Changes after failure',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotesPage())),
    );
    await settleUntil(tester, find.text('Saved on this device'));
    final field = tester.widget<TextField>(
      find.byKey(const Key('notes-editor')),
    );
    expect(
      field.controller!.text,
      Platform.isWindows ? 'First saved note' : 'Changes after failure',
    );
    expect(tester.takeException(), isNull);
  });
}
