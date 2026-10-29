import 'package:desksuite/app/theme.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sidebar uses consistent brand-toned icon tiles and a clear selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    WorkspaceSection? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: WorkspaceSidebar(
              section: WorkspaceSection.workspace,
              onNavigate: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    final selectedTile = find.byKey(const Key('nav-icon-tile-workspace'));
    final otherTile = find.byKey(const Key('nav-icon-tile-projects'));
    expect(selectedTile, findsOneWidget);
    expect(otherTile, findsOneWidget);

    final selectedBox = tester.widget<Container>(selectedTile);
    final otherBox = tester.widget<Container>(otherTile);
    final selectedDecoration = selectedBox.decoration! as BoxDecoration;
    final otherDecoration = otherBox.decoration! as BoxDecoration;
    expect(selectedDecoration.color!.a, greaterThan(otherDecoration.color!.a));
    expect(
      tester.widget<Icon>(
        find.descendant(of: selectedTile, matching: find.byType(Icon)),
      ).color,
      accent,
    );

    await tester.tap(find.byKey(const Key('nav-projects')));
    await tester.pump();
    expect(selected, WorkspaceSection.projects);
    expect(tester.takeException(), isNull);
  });
}
