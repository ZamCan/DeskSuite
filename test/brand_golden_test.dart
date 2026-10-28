import 'dart:io';

import 'package:desksuite/app/brand.dart';
import 'package:desksuite/app/zamcan_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the real logo widgets to images.
///
/// These goldens are the reference the owner can look at: they are produced by
/// the same painter the sidebar, the boot screen and the launcher icon use, so
/// the picture cannot drift from the app. Run with `--update-goldens` after a
/// deliberate design change.
Future<void> _loadFonts() async {
  final loader = FontLoader('DeskSuiteSans');
  for (final file in [
    'assets/fonts/NotoSans-Regular.ttf',
    'assets/fonts/NotoSans-Bold.ttf',
  ]) {
    final bytes = File(file).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('the mark on its tile', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: ZamCanBrand.ink,
          child: Center(child: ZamCanMark(size: 360)),
        ),
      ),
    );
    await expectLater(
      find.byType(ZamCanMark),
      matchesGoldenFile('goldens/zamcan-mark.png'),
    );
  });

  testWidgets('the lockup used by the sidebar, onboarding and boot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'DeskSuiteSans',
          colorScheme: ColorScheme.fromSeed(seedColor: ZamCanBrand.accent),
          scaffoldBackgroundColor: ZamCanBrand.paper,
          extensions: const [ZamCanColors.light],
        ),
        home: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    ZamCanMark(size: 132),
                    SizedBox(width: 28),
                    ZamCanWordmark(),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 420,
                  height: 90,
                  child: CustomPaint(
                    painter: ScanFramePainter(
                      phase: .18,
                      color: ZamCanBrand.accent,
                      lineColor: ZamCanBrand.accentSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/zamcan-lockup.png'),
    );
  });

  testWidgets('a half-drawn frame, as the boot animation shows it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: ZamCanBrand.paper,
          child: Center(
            child: ZamCanMark(
              size: 300,
              tile: false,
              drawProgress: .55,
              foreground: ZamCanBrand.ink,
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(ZamCanMark),
      matchesGoldenFile('goldens/zamcan-mark-drawing.png'),
    );
  });
}
