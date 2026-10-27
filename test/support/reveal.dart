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
}) async {
  await tester.pumpAndSettle();
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    return;
  }
  final scrollables = find.byType(Scrollable);
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
