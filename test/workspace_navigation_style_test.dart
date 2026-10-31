import 'package:desksuite/app/theme.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sidebar uses a consistent icon family and clear selection', (
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

    final selectedTile = find.byKey(const Key('nav-workspace'));
    final otherTile = find.byKey(const Key('nav-projects'));
    expect(selectedTile, findsOneWidget);
    expect(otherTile, findsOneWidget);
    final selectedIcon = tester.widget<Icon>(
      find.descendant(of: selectedTile, matching: find.byType(Icon)),
    );
    final otherIcon = tester.widget<Icon>(
      find.descendant(of: otherTile, matching: find.byType(Icon)),
    );
    expect(selectedIcon.color, accent);
    expect(otherIcon.color, Theme.of(tester.element(otherTile)).colorScheme.onSurfaceVariant);

    await tester.tap(otherTile);
    await tester.pump();
    expect(selected, WorkspaceSection.projects);
    expect(tester.takeException(), isNull);
  });
}
