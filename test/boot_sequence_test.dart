import 'package:desksuite/app/boot_sequence.dart';
import 'package:desksuite/app/brand.dart';
import 'package:desksuite/app/zamcan_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ZamCanBrand.accent),
    extensions: const [ZamCanColors.light],
  ),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: child,
  ),
);

void main() {
  testWidgets('draws the mark, then hands over once', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      _host(
        BootSequence(
          duration: const Duration(milliseconds: 400),
          onComplete: () => completed++,
        ),
      ),
    );
    // The first frame is the start of the drawing, not the finished logo.
    final first = tester.widget<ZamCanMark>(find.byKey(const Key('boot-logo')));
    expect(first.drawProgress, lessThan(.2));
    expect(completed, 0);

    // The scanning frame belongs to a painter, so it is found by painting, not
    // by widget type, and it appears shortly after the drawing starts.
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ScanFramePainter,
      ),
      findsOneWidget,
    );
    final middle = tester.widget<ZamCanMark>(
      find.byKey(const Key('boot-logo')),
    );
    expect(middle.drawProgress, greaterThan(first.drawProgress));
    expect(middle.drawProgress, lessThan(1));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(completed, 1);
  });

  testWidgets('the finished frame is the completed logo', (tester) async {
    await tester.pumpWidget(
      _host(
        BootSequence(
          duration: const Duration(milliseconds: 100),
          onComplete: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final done = tester.widget<ZamCanMark>(find.byKey(const Key('boot-logo')));
    expect(done.drawProgress, 1);
    // The bracket frame is gone once the drawing has finished.
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ScanFramePainter,
      ),
      findsNothing,
    );
  });

  testWidgets('reduced motion skips straight to the finished mark', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      _host(
        BootSequence(
          duration: const Duration(seconds: 2),
          onComplete: () => completed++,
        ),
        disableAnimations: true,
      ),
    );
    await tester.pump();
    final mark = tester.widget<ZamCanMark>(find.byKey(const Key('boot-logo')));
    expect(mark.drawProgress, 1);
    expect(completed, 1);
    // Nothing keeps animating, so the next screen is not delayed by a ticker
    // that never settles.
    await tester.pumpAndSettle();
  });

  testWidgets('the boot screen is branded, not a generic spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        BootSequence(
          duration: const Duration(milliseconds: 100),
          onComplete: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('DeskSuite'), findsOneWidget);
    expect(find.text('BY ZAMCAN'), findsOneWidget);
    expect(find.text(ZamCanBrand.tagline), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('completion is reported once even if frames keep coming', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      _host(
        BootSequence(
          duration: const Duration(milliseconds: 60),
          onComplete: () => completed++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, 1);
  });

  testWidgets('the scan frame changes shape as it zooms', (tester) async {
    // Two different phases must not paint identical frames, otherwise the
    // "zoomed in and out" motion is a static decoration.
    final a = ScanFramePainter(phase: 0, color: ZamCanBrand.accent);
    final b = ScanFramePainter(phase: .5, color: ZamCanBrand.accent);
    expect(a.shouldRepaint(a), isFalse);
    expect(a.shouldRepaint(b), isTrue);
  });
}
