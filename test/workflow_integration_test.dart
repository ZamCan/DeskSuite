import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/design/design_controller.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/design/design_renderer.dart';
import 'package:desksuite/printing/design_export.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final sampleImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAMCAIAAADkharWAAAAF0lEQVR4nGPs2VLBQApgIkn1qIYRpAEADVwB0JlVGsIAAAAASUVORK5CYII=',
);

void main() {
  testWidgets(
    'offline create, edit, undo, save, reopen, PNG and PDF workflow',
    (tester) async {
      await tester.runAsync(() async {
        await HttpOverrides.runZoned(
          () async {
            final directory = await Directory.systemTemp.createTemp(
              'desksuite_integration_',
            );
            final cache = DesignImageCache();
            try {
              final repo = ProjectRepository(directory);
              var doc = DesignDocument.blank(
                name: 'Print project',
                widthMm: 100,
                heightMm: 150,
              );
              final controller = DesignController(doc);
              controller.add(
                DesignElement(
                  id: 'shape',
                  kind: ElementKind.rectangle,
                  x: 10,
                  y: 10,
                  width: 40,
                  height: 30,
                  color: 0xffbd694f,
                ),
              );
              controller.add(
                DesignElement(
                  id: 'words',
                  kind: ElementKind.text,
                  x: 10,
                  y: 50,
                  width: 75,
                  height: 20,
                  text: 'Hello offline',
                  fontSizePt: 18,
                ),
              );
              controller.add(
                DesignElement(
                  id: 'photo',
                  kind: ElementKind.image,
                  x: 10,
                  y: 80,
                  width: 60,
                  height: 45,
                  imageBytes: Uint8List.fromList(sampleImage),
                ),
              );
              controller.beginGesture(const Offset(20, 90), handleRadiusMm: 2);
              controller.updateGesture(const Offset(5, 6));
              controller.endGesture();
              expect(controller.selected!.x, 15);
              controller.undo();
              expect(controller.selected!.x, 10);
              controller.redo();
              expect(controller.selected!.x, 15);
              doc = controller.document;
              await repo.save(doc);
              final reopened = await ProjectRepository(directory).load(doc.id);
              expect(reopened.elements.map((e) => e.id), [
                'shape',
                'words',
                'photo',
              ]);
              expect(reopened.elements.last.x, 15);
              expect(
                reopened.elements.last.imageBytes,
                orderedEquals(sampleImage),
              );
              await cache.sync(reopened);
              final duplicate = reopened.copyWith(
                elements: [
                  ...reopened.elements,
                  reopened.elements.last.copyWith(id: 'photo_copy', x: 20),
                ],
              );
              await cache.sync(duplicate);
              expect(
                identical(cache.images['photo'], cache.images['photo_copy']),
                isTrue,
              );
              await cache.sync(
                duplicate.copyWith(
                  elements: duplicate.elements
                      .where((e) => e.id != 'photo')
                      .toList(),
                ),
              );
              expect(cache.images['photo_copy']!.width, 16);
              await cache.sync(reopened);
              final png = await renderPng(reopened, cache.images, dpi: 100);
              final pdf = await renderPdf(reopened, cache.images, dpi: 100);
              expect(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
              expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
              expect(
                latin1.decode(pdf, allowInvalid: true),
                contains('/MediaBox'),
              );
              controller.dispose();
            } finally {
              cache.dispose();
              await directory.delete(recursive: true);
            }
          },
          createHttpClient: (_) =>
              throw StateError('Network access is blocked for this test'),
        );
      });
    },
  );
}
