import 'dart:async';

import 'package:desksuite/app/brand_launch.dart';
import 'package:desksuite/app/startup_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _surface = Key('brand-launch-surface');

/// A launch whose collaborators resolve immediately unless overridden.
Widget _launch({
  Widget child = const Scaffold(body: Text('Ready')),
  Future<bool>? showWelcome,
  Future<void>? workspaceReady,
  Future<void> Function()? onWelcomeCompleted,
}) => BrandLaunch(
  showWelcome: showWelcome ?? Future<bool>.value(false),
  workspaceReady: workspaceReady ?? Future<void>.value(),
  onWelcomeCompleted: onWelcomeCompleted ?? () async {},
  child: child,
);

void main() {
  testWidgets('failed workspace initialization does not trap startup', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(home: _launch(workspaceReady: ready.future)),
    );
    ready.completeError(StateError('failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed preference read does not trap startup', (tester) async {
    final welcome = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(home: _launch(showWelcome: welcome.future)),
    );
    welcome.completeError(StateError('failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace errors are handled while preferences are pending', (
    tester,
  ) async {
    final ready = Completer<void>();
    final welcome = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: _launch(
          workspaceReady: ready.future,
          showWelcome: welcome.future,
        ),
      ),
    );
    ready.completeError(StateError('storage unavailable'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    welcome.complete(false);
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup shows wordmark then transitions to brand mark', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _launch()));
    expect(find.text('DeskSuite'), findsOneWidget);
    expect(find.byKey(const Key('startup-wordmark')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.byKey(_surface), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('startup has no welcome copy or falling stationery', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _launch(showWelcome: Future<bool>.value(true))));
    expect(find.text('Welcome to DeskSuite'), findsNothing);
    expect(find.byType(WorkspaceLoadingView), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup covers the workspace, then reveals it', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _launch()));
    expect(find.byKey(_surface), findsOneWidget);
    expect(find.byType(WorkspaceLoadingView), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(find.byType(WorkspaceLoadingView), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup blocks input, then returns it to the workspace', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _launch(
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
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(220, 180),
            textScaler: TextScaler.linear(2.5),
          ),
          child: _launch(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('reduced motion still returns control to the workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _launch(),
        ),
      ),
    );
    // Reduced motion stops the loading animation, so no frame is scheduled and
    // pumpAndSettle would return before the handoff timer fires. Advance time
    // explicitly past the 1050 ms handoff, then let the fade finish.
    await tester.pump(const Duration(milliseconds: 1150));
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first run records the launch preference exactly once', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _launch(
          showWelcome: Future<bool>.value(true),
          onWelcomeCompleted: () async {
            completed++;
          },
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<WorkspaceLoadingView>(find.byType(WorkspaceLoadingView))
          .showWelcome,
      isTrue,
    );
    expect(completed, 0, reason: 'recorded only after the launch has run');

    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(find.byKey(_surface), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('a returning launch never rewrites the welcome preference', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _launch(
          showWelcome: Future<bool>.value(false),
          onWelcomeCompleted: () async {
            completed++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(completed, 0);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('a failed preference write never traps the user on startup', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _launch(
          showWelcome: Future<bool>.value(true),
          onWelcomeCompleted: () async {
            throw StateError('preference could not be saved');
          },
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
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsNothing);
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
