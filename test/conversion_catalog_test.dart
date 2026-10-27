import 'package:desksuite/workspace/conversion_catalog.dart';
import 'package:desksuite/workspace/conversion_catalog_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

void main() {
  test('registry only enables routes with a defined real destination', () {
    // Every target in the enum must be reachable from a real route; the count
    // is derived so adding a route cannot silently make the catalogue lie.
    final available = conversionRoutes.where((route) => route.available);
    expect(
      available.map((route) => route.target),
      containsAll(ConversionTarget.values),
    );
    expect(available, hasLength(ConversionTarget.values.length));
    expect(conversionRoutes.length - available.length, 1);
  });

  testWidgets(
    'phone catalogue opens each available target and labels unavailable routes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <ConversionTarget>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(body: ConversionCatalogPage(onOpen: opened.add)),
        ),
      );
      for (final target in ConversionTarget.values) {
        final button = find.byKey(Key('conversion-${target.name}'));
        await reveal(tester, button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pump();
      }
      expect(opened, ConversionTarget.values);
      for (final route in conversionRoutes.where((route) => !route.available)) {
        final title = find.text(route.title);
        await reveal(tester, title);
        final card = find.ancestor(of: title, matching: find.byType(Card));
        expect(
          find.descendant(of: card, matching: find.text('Not available')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.byType(OutlinedButton)),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
