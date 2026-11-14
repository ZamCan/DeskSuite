import 'package:desksuite/app/startup_view.dart';
import 'package:desksuite/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first launch shows the brand without welcome copy', (
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
    expect(find.text('Welcome to DeskSuite'), findsNothing);
    expect(find.text('DeskSuite'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning launch transitions from wordmark to icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.dark),
        home: const WorkspaceLoadingView(),
      ),
    );
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('Welcome to DeskSuite'), findsNothing);
    expect(find.text('DeskSuite'), findsOneWidget);
    expect(find.text('CREATIVE WORKSPACE'), findsNothing);
    await tester.pumpAndSettle();
    final logoOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.byType(BrandMark), matching: find.byType(Opacity)),
    );
    final wordOpacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const Key('startup-wordmark')),
        matching: find.byType(Opacity),
      ),
    );
    expect(logoOpacity.opacity, 1);
    expect(wordOpacity.opacity, 0);
    expect(tester.takeException(), isNull);
  });
}
