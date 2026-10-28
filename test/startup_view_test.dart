import 'package:desksuite/app/startup_view.dart';
import 'package:desksuite/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup uses the canonical DeskSuite mark and local-first copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.light),
        home: const WorkspaceLoadingView(),
      ),
    );

    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('DeskSuite'), findsOneWidget);
    expect(find.text('Documents, photos and print'), findsOneWidget);
    expect(find.text('Preparing your local workspace…'), findsOneWidget);
    expect(find.byKey(const Key('workspace-startup-progress')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup remains legible in dark appearance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.dark),
        home: const WorkspaceLoadingView(),
      ),
    );
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('DeskSuite'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
