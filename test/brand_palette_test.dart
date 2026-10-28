import 'dart:io';

import 'package:desksuite/app/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the one thing a design system cannot survive: a stray hex value.
///
/// Every colour literal in `lib/` must be a token in `app/brand.dart`, and the
/// launcher SVG must use exactly the same values. That is what "properly
/// branded" means in practice — not a style guide nobody applies, but a test
/// that fails when a fourth shade of terracotta appears.
void main() {
  final allowed = {
    for (final color in ZamCanBrand.allowed)
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
  };

  test('every colour literal in lib/ is a brand token', () {
    final offenders = <String>[];
    final pattern = RegExp(r'Color\(0x([0-9a-fA-F]{8})\)');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The token file is where literals are allowed to be defined.
      if (entity.path.endsWith('app/brand.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final hex = '#${match.group(1)!.toUpperCase()}';
        if (!allowed.contains(hex)) {
          final line = source.substring(0, match.start).split('\n').length;
          offenders.add('${entity.path}:$line uses $hex');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Add the colour to app/brand.dart (or use an existing token) instead '
          'of inventing a value:\n${offenders.join('\n')}',
    );
  });

  test('the launcher artwork uses the brand palette and nothing else', () {
    final svg = File('assets/brand/desksuite-mark.svg').readAsStringSync();
    final fills = RegExp(r'fill="(#[0-9a-fA-F]{6})"')
        .allMatches(svg)
        .map((m) => m.group(1)!.toUpperCase())
        .toSet();
    expect(fills, isNotEmpty);
    expect(
      fills.difference(allowed),
      isEmpty,
      reason:
          'assets/brand/desksuite-mark.svg uses colours outside the palette',
    );
  });

  test('the mark is drawn from the same geometry the SVG declares', () {
    // Bounds of the traced paths must sit inside the 512 box, and the crease
    // must match the rect in the SVG. A silently moved control point shows up
    // here rather than as a logo that looks slightly wrong on a phone.
    final bounds = ZamCanGeometry.dPath.getBounds().expandToInclude(
      ZamCanGeometry.sPath.getBounds(),
    );
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.top, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(ZamCanGeometry.box));
    expect(bounds.bottom, lessThanOrEqualTo(ZamCanGeometry.box));
    expect(ZamCanGeometry.crease, const Rect.fromLTWH(200, 273, 42, 10));

    final svg = File('assets/brand/desksuite-mark.svg').readAsStringSync();
    expect(svg, contains('x="200" y="273" width="42" height="10"'));
    expect(svg, contains('scale(1.25)'));
    expect(ZamCanGeometry.scale, 1.25);
  });

  test('brand tokens are internally consistent', () {
    // Ink on paper is readable in both directions, and the accent has enough
    // contrast to be used for text at 12 sp.
    double luminance(Color color) => color.computeLuminance();
    double contrast(Color a, Color b) {
      final la = luminance(a) + .05;
      final lb = luminance(b) + .05;
      return la > lb ? la / lb : lb / la;
    }

    expect(contrast(ZamCanBrand.ink, ZamCanBrand.paper), greaterThan(7));
    expect(
      contrast(ZamCanBrand.accentDeep, ZamCanBrand.paper),
      greaterThan(4.5),
    );
    expect(contrast(ZamCanBrand.accentSoft, ZamCanBrand.ink), greaterThan(4.5));
    // The two overlays that sit on ink must stay distinguishable from it.
    expect(ZamCanBrand.accent, isNot(ZamCanBrand.accentSoft));
  });
}
