import 'package:desksuite/app/startup_view.dart';
import 'package:desksuite/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loading state stays quiet while local storage opens', (tester) async {
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

    expect(find.byType(BrandMark), findsNothing);
    expect(find.text('DeskSuite'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Documents, photos and print'), findsNothing);
    expect(find.text('Preparing your local workspace…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading state remains legible in dark appearance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.dark),
        home: const WorkspaceLoadingView(),
      ),
    );
    expect(find.byType(BrandMark), findsNothing);
    expect(find.text('DeskSuite'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
