import 'package:desksuite/app/theme.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    final light = x > y ? x : y, dark = x > y ? y : x;
    return (light + .05) / (dark + .05);
  }

  test('brand primary and surface text colors meet normal-text contrast', () {
    for (final brightness in Brightness.values) {
      final colors = deskTheme(brightness).colorScheme;
      expect(
        contrast(colors.primary, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(colors.onSurface, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('selected brand PNG is bundled and used by the sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await rootBundle.load(deskSuiteBrandAsset);
    final raw = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    expect(raw.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SizedBox(
              width: 246,
              child: WorkspaceSidebar(
                section: WorkspaceSection.workspace,
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mark = find.byType(BrandMark);
    expect(mark, findsOneWidget);
    expect(
      find.descendant(of: mark, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
