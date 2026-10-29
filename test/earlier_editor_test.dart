import 'dart:convert';
import 'dart:io';

import 'package:desksuite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

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
      // Wait for the actual save acknowledgement rather than a fixed delay;
      // real file I/O takes longer on some hosted Windows runners.
      await settleUntil(tester, find.text('Earlier editor · manual save'));
      final saved = File(
        '${dir.path}/desksuite/projects/old-project.dsproject',
      );
      expect(await tester.runAsync(saved.exists), isTrue);
      final contents = await tester.runAsync(saved.readAsString);
      final document = jsonDecode(contents!) as Map<String, dynamic>;
      expect(document['id'], 'old-project');
      final items = document['items'] as List<dynamic>;
      expect(items, hasLength(1));
      expect((items.single as Map<String, dynamic>)['kind'], 'rect');
      expect(find.text('Earlier editor · manual save'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Open earlier'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
