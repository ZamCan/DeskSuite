import 'package:desksuite/app/theme.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task columns adapt to width and the user text scale', () {
    expect(workspaceTaskColumnCount(250, 1), 1);
    expect(workspaceTaskColumnCount(312, 1), 2);
    expect(workspaceTaskColumnCount(720, 1), 3);
    expect(workspaceTaskColumnCount(1050, 1), 4);
    expect(workspaceTaskColumnCount(312, 1.5), 1);
    expect(workspaceTaskColumnCount(720, 1.5), 2);
    expect(workspaceTaskColumnCount(720, 2), 1);
    expect(workspaceTaskColumnCount(1050, 2), 2);
  });

  testWidgets('neighboring task cards align and remain tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WorkspaceSection? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 312,
              child: WorkspaceTaskGrid(
                columns: 2,
                cards: [
                  WorkspaceToolCard(
                    key: const Key('short-task'),
                    section: WorkspaceSection.scans,
                    title: 'Scan documents',
                    description: 'Capture pages.',
                    onNavigate: (value) => opened = value,
                  ),
                  WorkspaceToolCard(
                    key: const Key('long-task'),
                    section: WorkspaceSection.photos,
                    title: 'Edit a photo',
                    description: 'Adjust, resize and prepare a separate image copy for your project.',
                    onNavigate: (value) => opened = value,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final short = tester.getRect(find.byKey(const Key('short-task')));
    final long = tester.getRect(find.byKey(const Key('long-task')));
    expect(short.top, long.top);
    expect(short.bottom, long.bottom);
    expect(short.right, lessThan(long.left));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Edit a photo'));
    expect(opened, WorkspaceSection.photos);
  });

  testWidgets('large text grows cards without clipping the controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: WorkspaceTaskGrid(
                  columns: 1,
                  cards: [
                    WorkspaceToolCard(
                      section: WorkspaceSection.office,
                      title: 'Convert a document',
                      description: 'Read and convert supported document content locally.',
                      onNavigate: (_) => opened = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Convert a document'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Convert a document'));
    expect(opened, isTrue);
  });
}
