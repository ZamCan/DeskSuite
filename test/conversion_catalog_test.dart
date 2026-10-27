import 'package:desksuite/workspace/conversion_catalog.dart';
import 'package:desksuite/workspace/conversion_catalog_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry only enables routes with a defined real destination', () {
    expect(conversionRoutes.where((route) => route.available), hasLength(5));
    expect(conversionRoutes.where((route) => !route.available), hasLength(3));
    expect(
      conversionRoutes
          .where((route) => route.available)
          .map((route) => route.target),
      containsAll(ConversionTarget.values),
    );
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
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pump();
      }
      expect(opened, ConversionTarget.values);
      for (final route in conversionRoutes.where((route) => !route.available)) {
        final title = find.text(route.title);
        await tester.scrollUntilVisible(
          title,
          200,
          scrollable: find.byType(Scrollable).first,
        );
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
