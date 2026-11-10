import 'package:desksuite/app/theme.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the type scale uses the two weights the bundled font ships', () {
    for (final brightness in Brightness.values) {
      final text = deskTheme(brightness).textTheme;
      final scale = <TextStyle>[
        text.displayLarge!,
        text.displayMedium!,
        text.displaySmall!,
        text.headlineLarge!,
        text.headlineMedium!,
        text.headlineSmall!,
        text.titleLarge!,
        text.titleMedium!,
        text.titleSmall!,
        text.bodyLarge!,
        text.bodyMedium!,
        text.bodySmall!,
        text.labelLarge!,
        text.labelMedium!,
        text.labelSmall!,
      ];
      for (final style in scale) {
        // DeskSuiteSans bundles Regular and Bold only; anything else would be
        // rendered as synthesised weight and break the visual hierarchy.
        expect(style.fontWeight, anyOf(FontWeight.w400, FontWeight.w700));
        expect(style.fontFamily, 'DeskSuiteSans');
        expect(style.height, isNotNull);
      }
      // Display sizes must out-rank headings, which out-rank body text.
      expect(text.displayLarge!.fontSize, greaterThan(text.headlineLarge!.fontSize!));
      expect(text.headlineSmall!.fontSize, greaterThan(text.titleLarge!.fontSize!));
      expect(text.titleLarge!.fontSize, greaterThan(text.bodyLarge!.fontSize!));
      expect(text.bodyLarge!.fontSize, greaterThan(text.labelSmall!.fontSize!));
      // Eyebrow labels are tracked; headings are tightened.
      expect(text.labelSmall!.letterSpacing, greaterThan(1));
      expect(text.headlineSmall!.letterSpacing, lessThan(0));
    }
  });

  test('shell surfaces share one radius, border and elevation recipe', () {
    for (final brightness in Brightness.values) {
      final theme = deskTheme(brightness);
      final card = theme.cardTheme;
      final shape = card.shape! as RoundedRectangleBorder;
      expect(
        (shape.borderRadius as BorderRadius).topLeft.x,
        duneCardRadius,
      );
      expect(shape.side.width, 1);
      expect(shape.side.color, isNot(Colors.transparent));
      expect(card.elevation, 0);
      expect(theme.appBarTheme.toolbarHeight, 68);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.drawerTheme.width, 288);
      expect(duneShadow(brightness), isNotEmpty);
    }
  });

  testWidgets('a tool card keeps its section tone and needs no backdrop blur', (
    tester,
  ) async {
    for (final section in [
      WorkspaceSection.scans,
      WorkspaceSection.pdfStudio,
      WorkspaceSection.photos,
      WorkspaceSection.text,
      WorkspaceSection.office,
      WorkspaceSection.design,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: deskTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: WorkspaceToolCard(
                section: section,
                title: 'Section',
                description: 'Description',
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      );
      final scheme = Theme.of(
        tester.element(find.byType(WorkspaceToolCard)),
      ).colorScheme;
      // Every workspace tone is drawn from the shared Dune studio family.
      expect(duneToneForSection(section, scheme), isNot(Colors.transparent));
      // Cards sit on a gradient, so a live backdrop blur would only cost frames.
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the drawer marks the current section with the accent wash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(Brightness.dark),
        home: Scaffold(
          body: SizedBox(
            width: 288,
            child: WorkspaceSidebar(
              section: WorkspaceSection.scans,
              onNavigate: (_) {},
            ),
          ),
        ),
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byKey(const Key('nav-scans'))),
    ).colorScheme;
    final selectedIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('nav-scans')),
        matching: find.byType(Icon),
      ),
    );
    final otherIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('nav-photos')),
        matching: find.byType(Icon),
      ),
    );
    expect(selectedIcon.color, scheme.primary);
    expect(otherIcon.color, scheme.onSurfaceVariant);
    // The header keeps the brand mark and names the offline contract.
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('On-device workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
