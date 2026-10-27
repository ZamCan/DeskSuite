import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/workspace/external_file_opener.dart';

void main() {
  group('ExternalFileOpener MIME mapping', () {
    test('recognizes common office and document formats', () {
      expect(ExternalFileOpener.mimeTypeForName('letter.docx'),
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(ExternalFileOpener.mimeTypeForName('budget.xlsx'),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      expect(ExternalFileOpener.mimeTypeForName('slides.pptx'),
          'application/vnd.openxmlformats-officedocument.presentationml.presentation');
      expect(ExternalFileOpener.mimeTypeForName('scan.pdf'), 'application/pdf');
    });

    test('extension matching is case-insensitive', () {
      expect(ExternalFileOpener.mimeTypeForName('REPORT.PDF'), 'application/pdf');
    });

    test('unknown formats are not mislabeled as supported documents', () {
      expect(ExternalFileOpener.mimeTypeForName('unknown.bin'),
          'application/octet-stream');
    });
  });
}
