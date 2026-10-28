import 'package:desksuite/core/file_limits.dart';
import 'package:desksuite/office/office_package.dart';
import 'package:desksuite/pdf/pdf_combine.dart';
import 'package:desksuite/pdf/pdf_inspection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Office archive and PDF use the shared document byte budget', () {
    expect(maxDocumentBytes, 48 * 1024 * 1024);
    expect(OfficePackageLimits.maxArchiveBytes, maxDocumentBytes);
    expect(maxPdfBytes, maxDocumentBytes);
    expect(maxPdfCombineBytes, maxDocumentBytes);
  });
}
