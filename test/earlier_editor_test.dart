import 'dart:io';

import 'package:desksuite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets(
    'earlier editor protects manual unsaved changes and can save before leaving',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('desksuite_old_editor_'),
      ))!;
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => dir.path,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        EditorPage(project: Project(id: 'old-project')),
                  ),
                ),
                child: const Text('Open earlier'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open earlier'));
      await tester.pumpAndSettle();
      expect(find.text('Earlier editor · manual save'), findsOneWidget);
      await tester.tap(find.text('Shape'));
      await tester.pump();
      expect(find.text('Unsaved · manual save'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved earlier design'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save earlier design'));
      await settleIo(tester);
      expect(
        await tester.runAsync(
          () =>
              File('${dir.path}/desksuite/projects/old-project.dsproject')
                  .exists(),
        ),
        isTrue,
      );
      expect(find.text('Earlier editor · manual save'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Open earlier'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
