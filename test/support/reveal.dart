import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scrolls a lazily built [ListView] until [target] has been built, then brings
/// it into the viewport.
///
/// `WidgetController.ensureVisible` throws `Bad state: No element` when the
/// finder matches nothing, which happens for children a lazy list has not
/// created yet. Tests must scroll first; this helper searches down and then
/// back up so it works regardless of the current scroll offset.
Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  int maxScrolls = 40,
  double step = 220,
  Finder? within,
}) async {
  await tester.pumpAndSettle();
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    return;
  }
  final scrollables = within == null
      ? find.byType(Scrollable)
      : find.descendant(of: within, matching: find.byType(Scrollable));
  if (scrollables.evaluate().isEmpty) {
    fail('No scrollable found while revealing the target widget.');
  }
  final scrollable = scrollables.first;
  for (final direction in <double>[-1, 1]) {
    for (var i = 0; i < maxScrolls; i++) {
      await tester.drag(scrollable, Offset(0, direction * step));
      await tester.pumpAndSettle();
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        return;
      }
    }
  }
  fail('Could not reveal the target widget after scrolling.');
}

/// Pumps and yields to real asynchronous work until [target] appears or the
/// wall-clock budget expires.
///
/// Image decoding and isolates take different amounts of real time on different
/// operating systems, so a fixed number of pump rounds is not a reliable wait.
Future<void> settleUntil(
  WidgetTester tester,
  Finder target, {
  Duration timeout = const Duration(seconds: 30),
  int stepMs = 30,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(Duration(milliseconds: stepMs));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (target.evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
  fail('Timed out after ${timeout.inSeconds}s waiting for a widget to appear.');
}
