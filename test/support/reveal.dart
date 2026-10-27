import 'package:flutter/material.dart';
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

/// Waits until the widget matched by [target] accepts a tap.
///
/// The scan screen disables every control while a page is being processed or
/// saved. A test that taps a disabled button changes nothing and then waits for
/// a result that will never appear, which is how the Windows CI job failed while
/// Linux passed: the same work simply finished later there. Waiting for the
/// control to become enabled is an assertion about the app, not a longer sleep.
Future<void> settleUntilEnabled(
  WidgetTester tester,
  Finder target, {
  Duration timeout = const Duration(seconds: 30),
  int stepMs = 30,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final matches = target.evaluate();
    if (matches.isEmpty) {
      fail('The target control is not in the widget tree.');
    }
    if (_acceptsTap(matches.first.widget)) {
      await tester.pump();
      return;
    }
    await tester.pump(Duration(milliseconds: stepMs));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('The target control stayed disabled for ${timeout.inSeconds}s.');
}

bool _acceptsTap(Widget widget) {
  if (widget is ButtonStyleButton) {
    return widget.onPressed != null || widget.onLongPress != null;
  }
  if (widget is IconButton) return widget.onPressed != null;
  if (widget is FloatingActionButton) return widget.onPressed != null;
  if (widget is InkWell) {
    return widget.onTap != null || widget.onLongPress != null;
  }
  if (widget is GestureDetector) return widget.onTap != null;
  // Generic widgets cannot be promoted here without a type argument, and
  // reading their callback throws a type error, so they are tapped as-is.
  return true;
}

/// Pumps and yields to real asynchronous work until [target] is gone.
///
/// Use this to wait for a screen to leave a transient state (a recovery banner,
/// a busy overlay) rather than guessing how many pump rounds that takes.
Future<void> settleUntilGone(
  WidgetTester tester,
  Finder target, {
  Duration timeout = const Duration(seconds: 30),
  int stepMs = 30,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (target.evaluate().isEmpty) {
      await tester.pump();
      return;
    }
    await tester.pump(Duration(milliseconds: stepMs));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail(
    'Timed out after ${timeout.inSeconds}s waiting for a widget to go away.',
  );
}

/// Runs real asynchronous work (file I/O, isolates) without ever hanging the
/// test.
///
/// `tester.runAsync` waits for the whole callback, and a repository or store
/// whose write queue was created in the fake-async zone will only finish that
/// queue when the test pumps. Awaiting such a read inside `runAsync` therefore
/// waits for something that cannot happen, which is how a Windows CI run sat
/// until the ten-minute test timeout. Each attempt here is bounded in real time
/// and the test pumps between attempts, so the queue drains and a genuine
/// failure is reported in seconds instead of minutes.
Future<T> settledIo<T>(
  WidgetTester tester,
  Future<T> Function() action, {
  Duration perAttempt = const Duration(milliseconds: 500),
  int attempts = 40,
  String label = 'value',
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < attempts; attempt++) {
    T? result;
    await tester.runAsync(() async {
      try {
        result = await action().timeout(perAttempt);
      } catch (error) {
        lastError = error;
      }
    });
    if (result != null) return result as T;
    await tester.pump(Duration(milliseconds: 25));
  }
  fail(
    'Could not read $label within ${attempts * perAttempt.inMilliseconds}ms: $lastError',
  );
}
