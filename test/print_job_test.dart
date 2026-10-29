import 'package:desksuite/printing/paper_catalog.dart';
import 'package:desksuite/printing/print_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final a4 = PrintMediaTarget.fromPreset(
    id: 'iso-a4',
    preset: paperSheetPresets.firstWhere(
      (preset) => preset.label.startsWith('A4 portrait'),
    ),
  );

  group('PrintJob geometry', () {
    test(
      'fit keeps the complete source inside A4 and preserves aspect ratio',
      () {
        final layout = PrintJob(
          media: a4,
          sourceWidthMm: 100,
          sourceHeightMm: 100,
          scalePolicy: PrintScalePolicy.fit,
          marginMm: 5,
        ).calculateLayout();

        expect(layout.scale, closeTo(2.0, 0.0001));
        expect(layout.widthMm, closeTo(200, 0.0001));
        expect(layout.heightMm, closeTo(200, 0.0001));
        expect(layout.cropXmm, 0);
        expect(layout.cropYmm, 0);
      },
    );

    test(
      'fillCrop reports crop instead of silently changing source geometry',
      () {
        final layout = PrintJob(
          media: a4,
          sourceWidthMm: 100,
          sourceHeightMm: 200,
          scalePolicy: PrintScalePolicy.fillCrop,
        ).calculateLayout();

        expect(layout.scale, closeTo(2.1, 0.0001));
        expect(layout.widthMm, closeTo(210, 0.0001));
        expect(layout.heightMm, closeTo(420, 0.0001));
        expect(layout.cropYmm, greaterThan(0));
      },
    );

    test('actual size does not enlarge a small original to fill the page', () {
      final layout = PrintJob(
        media: a4,
        sourceWidthMm: 50,
        sourceHeightMm: 70,
        scalePolicy: PrintScalePolicy.actualSize,
        marginMm: 4,
      ).calculateLayout();

      expect(layout.scale, 1);
      expect(layout.widthMm, 50);
      expect(layout.heightMm, 70);
      expect(layout.offsetXmm, greaterThan(4));
    });

    test('invalid or non-finite dimensions are rejected', () {
      final job = PrintJob(
        media: a4,
        sourceWidthMm: double.infinity,
        sourceHeightMm: 20,
      );
      expect(job.isValid, isFalse);
      expect(job.calculateLayout, throwsFormatException);
    });

    test(
      'finite but extreme geometry cannot produce infinity or zero scale',
      () {
        final tooSmall = PrintJob(
          media: a4,
          sourceWidthMm: double.minPositive,
          sourceHeightMm: double.minPositive,
        );
        expect(tooSmall.calculateLayout, throwsFormatException);
        const tinyMedia = PrintMediaTarget(
          id: 'tiny',
          label: 'Tiny',
          widthMm: double.minPositive,
          heightMm: double.minPositive,
        );
        final tooLarge = PrintJob(
          media: tinyMedia,
          sourceWidthMm: 1e308,
          sourceHeightMm: 1e308,
        );
        expect(tooLarge.calculateLayout, throwsFormatException);
      },
    );

    test('custom media target validates physical dimensions', () {
      expect(
        const PrintMediaTarget(
          id: 'custom',
          label: 'Custom',
          widthMm: 100,
          heightMm: 150,
        ).isValid,
        isTrue,
      );
      expect(
        const PrintMediaTarget(
          id: 'bad',
          label: 'Bad',
          widthMm: 0,
          heightMm: 150,
        ).isValid,
        isFalse,
      );
    });
  });

  group('PrinterCapabilities', () {
    test('unknown capabilities never imply a supported preset', () {
      const capabilities = PrinterCapabilities();
      expect(capabilities.supportsMedia(a4), isFalse);
      expect(capabilities.borderless, CapabilitySupport.unknown);
      expect(capabilities.duplex, CapabilitySupport.unknown);
    });

    test('only reported media IDs can be treated as supported', () {
      const capabilities = PrinterCapabilities(
        mediaSizes: CapabilitySupport.supported,
        reportedMediaIds: {'iso-a4'},
      );
      expect(capabilities.supportsMedia(a4), isTrue);
    });
  });

  test('print profile rejects invalid margins', () {
    final profile = PrintProfile(
      id: 'invalid',
      label: 'Invalid',
      media: a4,
      marginMm: 150,
    );
    expect(profile.isValid, isFalse);
  });
}
