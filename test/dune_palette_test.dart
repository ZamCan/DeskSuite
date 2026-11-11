import 'package:desksuite/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dune Phosphate keeps warm sand neutrals and a phosphate accent', () {
    for (final brightness in Brightness.values) {
      final theme = deskTheme(brightness);
      final scheme = theme.colorScheme;
      final primary = scheme.primary;
      // Phosphate teal: green and blue sit above red in the accent.
      expect(primary.g, greaterThan(primary.r));
      expect(primary.b, greaterThan(primary.r));
      // Surfaces stay warm sand, never a cold blue-grey.
      expect(
        theme.scaffoldBackgroundColor.r,
        greaterThan(theme.scaffoldBackgroundColor.b),
      );
      expect(scheme.surface.r, greaterThanOrEqualTo(scheme.surface.b));
      expect(scheme.onSurface.b, lessThanOrEqualTo(scheme.onSurface.r));
    }
    // Light and dark are two deliberate palettes, not one inverted.
    expect(
      deskTheme(Brightness.light).scaffoldBackgroundColor,
      isNot(deskTheme(Brightness.dark).scaffoldBackgroundColor),
    );
    expect(
      deskTheme(Brightness.dark).scaffoldBackgroundColor.computeLuminance(),
      lessThan(
        deskTheme(Brightness.light).scaffoldBackgroundColor.computeLuminance(),
      ),
    );
  });

  test('studio tones stay distinct and fully opaque', () {
    const tones = [
      SectionTones.scan,
      SectionTones.pdf,
      SectionTones.photo,
      SectionTones.text,
      SectionTones.docs,
      SectionTones.create,
      SectionTones.print,
      SectionTones.business,
    ];
    expect(tones.toSet().length, tones.length);
    for (final tone in tones) {
      expect(tone.a, 1.0);
    }
    expect(duneGradient.colors.length, 2);
    expect(duneGradient.colors.first, isNot(duneGradient.colors.last));
  });
}
