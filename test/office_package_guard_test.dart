import 'dart:convert';
import 'dart:typed_data';

import 'package:desksuite/office/office_package.dart';
import 'package:desksuite/office/office_zip_guard.dart';
import 'package:flutter_test/flutter_test.dart';

// Small stored ZIP made from fictional data for this project.
const _fixture =
    'UEsDBBQAAAAAAAAAIVxQW15CKgAAACoAAAARAAAAd29yZC9kb2N1bWVudC54bWw8ZG9jdW1lbnQ+RGVza1N1aXRlIG9mZmljZSB0ZXN0PC9kb2N1bWVudD5QSwMEFAAAAAAAAAAhXJh3Ke0JAAAACQAAAA8AAAB3b3JkL3N0eWxlcy54bWw8c3R5bGVzLz5QSwECFAMUAAAAAAAAACFcUFteQioAAAAqAAAAEQAAAAAAAAAAAAAApIEAAAAAd29yZC9kb2N1bWVudC54bWxQSwECFAMUAAAAAAAAACFcmHcp7QkAAAAJAAAADwAAAAAAAAAAAAAApIFZAAAAd29yZC9zdHlsZXMueG1sUEsFBgAAAAACAAIAfAAAAI8AAAAAAA==';

int _directory(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < bytes.length - 4; i++) {
    if (data.getUint32(i, Endian.little) == 0x02014b50) return i;
  }
  throw StateError('Missing central directory');
}

void main() {
  test('preflights and reads a valid stored package', () {
    final package = OfficePackage.open(base64.decode(_fixture));
    expect(package.textOf('word/document.xml'), contains('DeskSuite office'));
    expect(package.entryCount, 2);
  });

  test('checks actual CRC even though ZipDecoder verify is ineffective', () {
    final bytes = base64.decode(_fixture);
    bytes[30 + 'word/document.xml'.length + 5] ^= 1; // Stored content only.
    // Headers remain consistent, so the CRC check must catch the damage.
    expect(
      () => guardOfficeZip(
        bytes,
        maxEntries: 4000,
        maxEntryBytes: 24 << 20,
        maxTotalBytes: 64 << 20,
      ),
      returnsNormally,
    );
    expect(() => OfficePackage.open(bytes), throwsFormatException);
  });

  test('rejects a Unix symlink before the ZIP decoder can inflate it', () {
    final bytes = base64.decode(_fixture);
    final directory = _directory(bytes);
    ByteData.sublistView(bytes)
        .setUint32(directory + 38, 0xa1ff0000, Endian.little);
    expect(() => OfficePackage.open(bytes), throwsFormatException);
  });

  test('rejects a declared oversized part before decompression', () {
    final bytes = base64.decode(_fixture);
    final directory = _directory(bytes);
    ByteData.sublistView(bytes)
        .setUint32(directory + 24, 25 << 20, Endian.little);
    expect(() => OfficePackage.open(bytes), throwsFormatException);
  });
}
