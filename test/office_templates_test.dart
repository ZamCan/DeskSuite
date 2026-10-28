import 'dart:typed_data';

import 'package:desksuite/office/office_format.dart';
import 'package:desksuite/office/office_reader.dart';
import 'package:desksuite/office/office_template_catalog.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all six bundled OOXML templates are readable with expected content',
    () async {
      expect(officeTemplateCatalog, hasLength(6));
      expect(
        officeTemplateCatalog.map((item) => item.id).toSet(),
        hasLength(6),
      );
      for (final item in officeTemplateCatalog) {
        final data = await rootBundle.load(item.assetPath);
        final Uint8List bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final expected = switch (item.kind) {
          OfficeTemplateKind.word => OfficeFormat.docx,
          OfficeTemplateKind.spreadsheet => OfficeFormat.xlsx,
          OfficeTemplateKind.presentation => OfficeFormat.pptx,
        };
        expect(
          detectOfficeFile(bytes, fileName: item.fileName).format,
          expected,
          reason: item.fileName,
        );
        final document = readOfficeDocument(bytes, fileName: item.fileName);
        expect(document.blocks, isNotEmpty, reason: item.fileName);
        if (item.kind == OfficeTemplateKind.spreadsheet) {
          expect(document.sheetNames, ['Template', 'Read me']);
          // openpyxl writes an empty cached <v/>; retain the formula as text
          // instead of silently losing it. Export does not recalculate it.
          expect(document.tableText, contains('='));
        }
        if (item.kind == OfficeTemplateKind.presentation) {
          expect(document.slideCount, item.id == 'project-pitch' ? 4 : 3);
          expect(document.plainText, contains('Slide 2'));
        }
      }
    },
  );
}
