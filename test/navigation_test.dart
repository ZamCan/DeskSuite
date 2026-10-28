import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/main.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

class NoFiles implements FileGateway {
  @override
  Future<Uint8List?> pickImage() async => null;
  @override
  Future<Uint8List?> pickProject() async => null;
  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async => false;
}

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

/// Opens the navigation drawer and waits for it to be really open.
///
/// `find.byType(Drawer)` is useless as an "is it open" check because Scaffold
/// keeps the drawer mounted while it is closed and ignores taps on it, so a tap
/// aimed at a menu row silently misses. ScaffoldState knows the real answer.
/// The Scaffold that owns the navigation drawer.
///
/// The app nests Scaffolds per studio, so `find.byType(Scaffold).first` is not
/// necessarily the one holding the drawer; it is derived from the menu button.
ScaffoldState drawerHost(WidgetTester tester) => tester.state<ScaffoldState>(
  find
      .ancestor(
        of: find.byTooltip('Open navigation'),
        matching: find.byType(Scaffold),
      )
      .first,
);

/// Opens the navigation drawer and waits for the slide to finish.
///
/// The first call taps the real menu button, so the user-facing path is
/// exercised. Later calls drive `ScaffoldState` directly: while a drawer closes
/// Scaffold keeps a modal barrier over the screen, and on a 320 px phone that
/// barrier can still be fading when the next tap lands, which makes tapping the
/// button a coin flip.
Future<void> openDrawer(WidgetTester tester, {bool viaButton = false}) async {
  if (viaButton) {
    await tester.tap(find.byTooltip('Open navigation'));
  } else {
    drawerHost(tester).openDrawer();
  }
  var opened = false;
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    if (drawerHost(tester).isDrawerOpen) {
      opened = true;
      break;
    }
  }
  if (!opened) fail('The navigation drawer did not open.');
  // isDrawerOpen flips when the animation starts, and taps on a sliding drawer
  // are ignored, so let the slide finish before anything is tapped.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// Pumps until the navigation drawer has finished closing.
///
/// While the drawer closes, Scaffold keeps a modal barrier over the body that
/// swallows taps, and the barrier only goes away once the close animation has
/// run its course. pumpAndSettle cannot be used here (the drawer's scrollable
/// keeps an overscroll animation alive), so this pumps a bounded amount of
/// animation time instead.
Future<void> closeDrawer(WidgetTester tester) async {
  drawerHost(tester).closeDrawer();
  for (var i = 0; i < 20; i++) {
    if (!drawerHost(tester).isDrawerOpen) {
      // Let the barrier finish fading out.
      for (var j = 0; j < 6; j++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      return;
    }
    await tester.pump(const Duration(milliseconds: 40));
  }
  fail('The navigation drawer did not close.');
}

void main() {
  testWidgets(
    'small phone navigation reaches every studio and persists theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('desksuite_nav_'),
      ))!;
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final repo = ProjectRepository(dir);
      await tester.pumpWidget(
        DeskSuiteApp(
          showStartupAnimation: false,
          repository: repo,
          fileGateway: NoFiles(),
        ),
      );
      await settleIo(tester);

      // The menu button really opens the drawer on a 320 px phone.
      await openDrawer(tester, viaButton: true);
      expect(find.text('Photo Studio'), findsOneWidget);
      // There are no placeholder entries left: every listed studio is a real
      // screen, so no drawer row is disabled.
      expect(find.text('PLANNED'), findsNothing);

      // Settings: top of the list, and its switch is the persistence check.
      await tester.tap(find.byKey(const Key('nav-settings')));
      await settleUntil(tester, find.text('Dark appearance'));
      await closeDrawer(tester);
      // On a 320x640 phone the appearance switch is below the fold of the
      // settings list, so bring it into view before tapping it.
      final appearance = find.byType(SwitchListTile);
      await tester.ensureVisible(appearance);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(appearance);
      await settleIo(tester);
      expect(await tester.runAsync(() => repo.readDarkMode()), isTrue);

      // Every listed studio has to be reachable on a 320 px phone. The last
      // entries only exist once the lazy drawer list has been scrolled, so each
      // one is scrolled to before it is tapped.
      for (final section in WorkspaceSection.values) {
        final entryKey = Key('nav-${section.name}');
        final entry = find.byKey(entryKey);
        await openDrawer(tester);
        await scrollDrawerTo(tester, entry);
        await tester.ensureVisible(entry);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(entry);
        await closeDrawer(tester);
        // Reopen the drawer before looking for its selected row. A closed
        // drawer can be offstage, so finders must not assume it stays visible.
        await openDrawer(tester);
        await scrollDrawerTo(tester, entry);
        expect(
          tester.widget<ListTile>(entry).selected,
          isTrue,
          reason: 'the ${section.name} entry should be selected after tapping',
        );
        await closeDrawer(tester);
        expect(tester.takeException(), isNull, reason: section.name);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

/// Scrolls the open navigation drawer until [target] is built and on screen.
///
/// The drawer body is a lazy list, so the last entry does not exist until the
/// list has been scrolled, and on a 320 px phone that takes more than one
/// screen. Drags are issued from the drawer's centre point rather than at a
/// `Scrollable` widget: the scrollable's centre lands on a clipped area and
/// produces "would not hit test" warnings.
Future<void> scrollDrawerTo(WidgetTester tester, Finder target) async {
  final drawer = find.byType(Drawer);
  if (drawer.evaluate().isEmpty) fail('The navigation drawer is not open.');
  final origin = tester.getCenter(drawer);
  // Rewind to the top first so the search always runs in one direction.
  for (var i = 0; i < 12; i++) {
    await tester.dragFrom(origin, const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 60));
  }
  await tester.pump(const Duration(milliseconds: 200));
  for (var i = 0; i < 12; i++) {
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target);
      if (rect.top >= 0 && rect.bottom <= tester.view.physicalSize.height) {
        return;
      }
    }
    await tester.dragFrom(origin, const Offset(0, -160));
    await tester.pump(const Duration(milliseconds: 120));
  }
  if (target.evaluate().isEmpty) {
    fail('Could not scroll the navigation drawer to the requested entry.');
  }
}
