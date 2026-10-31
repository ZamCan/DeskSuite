import 'package:desksuite/app/brand_launch.dart';
import 'package:desksuite/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boot reveals the official mark before the app name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrandLaunch(child: Scaffold(body: Text('Ready'))),
      ),
    );
    expect(find.byKey(const Key('brand-launch-surface')), findsOneWidget);
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('DeskSuite'), findsOneWidget);
    expect(find.byKey(const Key('brand-launch-name')), findsOneWidget);
    expect(find.text('Documents · Design · Print · Business'), findsNothing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester.widget<Opacity>(find.byKey(const Key('brand-launch-artwork'))).opacity,
      greaterThan(0),
    );
    expect(
      tester.widget<Opacity>(find.byKey(const Key('brand-launch-name'))).opacity,
      greaterThan(0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brand-launch-surface')), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boot blocks input only until the short reveal completes', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BrandLaunch(
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continue'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
  });

  testWidgets('boot fits a short narrow screen with larger text', (tester) async {
    tester.view.physicalSize = const Size(220, 180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(220, 180),
            textScaler: TextScaler.linear(2.5),
          ),
          child: BrandLaunch(child: Scaffold(body: Text('Ready'))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion skips the boot reveal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: BrandLaunch(child: Scaffold(body: Text('Ready'))),
        ),
      ),
    );
    expect(find.byKey(const Key('brand-launch-surface')), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
