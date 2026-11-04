import 'package:desksuite/app/startup_view.dart';
import 'package:desksuite/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first launch shows the canonical icon and brief welcome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.light),
        home: const WorkspaceLoadingView(showWelcome: true),
      ),
    );

    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('Welcome to DeskSuite'), findsOneWidget);
    expect(find.text('DeskSuite'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning launch is icon-only and animated', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.dark),
        home: const WorkspaceLoadingView(),
      ),
    );
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('Welcome to DeskSuite'), findsNothing);
    expect(find.text('DeskSuite'), findsNothing);
    expect(find.text('CREATIVE WORKSPACE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
