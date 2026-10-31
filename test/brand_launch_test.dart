import 'package:desksuite/app/brand_launch.dart';
import 'package:desksuite/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup draws, reveals the selected logo and returns control', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrandLaunch(child: Scaffold(body: Text('Ready'))),
      ),
    );
    expect(find.byKey(const Key('brand-launch-surface')), findsOneWidget);
    expect(find.byKey(const Key('brand-launch-drawing')), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('brand-launch-artwork')))
          .opacity,
      0,
    );
    expect(find.byType(BrandMark), findsOneWidget);
    await tester.pump(); // Start the ticker before advancing fake time.
    await tester.pump(const Duration(milliseconds: 650));
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('brand-launch-artwork')))
          .opacity,
      greaterThan(0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brand-launch-surface')), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup blocks input, then returns it to the workspace', (
    tester,
  ) async {
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

  testWidgets('startup fits a short narrow screen with larger text', (
    tester,
  ) async {
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

  testWidgets('reduced motion skips the startup animation', (tester) async {
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
