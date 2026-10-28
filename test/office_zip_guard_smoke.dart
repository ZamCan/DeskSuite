import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:desksuite/office/office_zip_guard.dart';

// Fictional two-entry ZIP, generated for this project. The smoke can also run
// without Flutter by combining this file and office_zip_guard.dart under DDC.
const _zip =
    'UEsDBBQAAAAAAAAAIVxQW15CKgAAACoAAAARAAAAd29yZC9kb2N1bWVudC54bWw8ZG9jdW1lbnQ+RGVza1N1aXRlIG9mZmljZSB0ZXN0PC9kb2N1bWVudD5QSwMEFAAAAAAAAAAhXJh3Ke0JAAAACQAAAA8AAAB3b3JkL3N0eWxlcy54bWw8c3R5bGVzLz5QSwECFAMUAAAAAAAAACFcUFteQioAAAAqAAAAEQAAAAAAAAAAAAAApIEAAAAAd29yZC9kb2N1bWVudC54bWxQSwECFAMUAAAAAAAAACFcmHcp7QkAAAAJAAAADwAAAAAAAAAAAAAApIFZAAAAd29yZC9zdHlsZXMueG1sUEsFBgAAAAACAAIAfAAAAI8AAAAAAA==';

Map<String, OfficeZipEntry> check(
  Uint8List bytes, {
  int entries = 4000,
  int part = 24 * 1024 * 1024,
  int total = 64 * 1024 * 1024,
}) => guardOfficeZip(
  bytes,
  maxEntries: entries,
  maxEntryBytes: part,
  maxTotalBytes: total,
);

void rejects(
  String name,
  Uint8List bytes, {
  int entries = 4000,
  int part = 24 * 1024 * 1024,
  int total = 64 * 1024 * 1024,
}) {
  try {
    check(bytes, entries: entries, part: part, total: total);
  } on FormatException {
    return;
  }
  throw StateError('$name was not rejected');
}

Uint8List fresh() => base64.decode(_zip);

int signature(Uint8List bytes, int sig) {
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i <= bytes.length - 4; i++) {
    if (data.getUint32(i, Endian.little) == sig) return i;
  }
  throw StateError('fixture signature absent');
}

void main() {
  final good = fresh();
  final valid = check(good);
  if (valid.length != 2 || valid['word/document.xml']?.size != 42) {
    throw StateError('valid package did not pass');
  }
  rejects('entry count', fresh(), entries: 1);
  rejects('part size', fresh(), part: 41);
  rejects('total size', fresh(), total: 50);
  rejects('truncated', Uint8List.sublistView(good, 0, good.length - 1));

  var bad = fresh();
  var directory = signature(bad, 0x02014b50);
  var data = ByteData.sublistView(bad);
  data.setUint32(directory + 24, 0xffffffff, Endian.little);
  rejects('ZIP64 size', bad);

  bad = fresh();
  directory = signature(bad, 0x02014b50);
  data = ByteData.sublistView(bad);
  data.setUint32(directory + 38, 0xa1ff0000, Endian.little);
  rejects('symlink', bad);

  bad = fresh();
  directory = signature(bad, 0x02014b50);
  data = ByteData.sublistView(bad);
  data.setUint16(directory + 8, 1, Endian.little);
  rejects('encrypted', bad);

  bad = fresh();
  directory = signature(bad, 0x02014b50);
  bad[directory + 46] ^= 1;
  rejects('mismatched names', bad);

  bad = fresh();
  final end = signature(bad, 0x06054b50);
  data = ByteData.sublistView(bad);
  data.setUint16(end + 10, 1, Endian.little);
  rejects('false directory count', bad);

  // Exercise all truncation boundaries, including malformed headers, without
  // letting RangeError escape instead of a clean FormatException.
  for (var length = 0; length < good.length; length++) {
    rejects('truncation $length', Uint8List.sublistView(good, 0, length));
  }
  final random = math.Random(20261028);
  for (var i = 0; i < 3000; i++) {
    final mutated = fresh();
    for (var j = 0; j < 1 + random.nextInt(4); j++) {
      mutated[random.nextInt(mutated.length)] = random.nextInt(256);
    }
    try {
      check(mutated);
    } on FormatException {
      // Safe rejection is expected. Content mutations can pass structure and
      // are checked later by OfficePackage's CRC verification.
    }
  }
  print(
    'Office ZIP guard smoke passed: valid package, malformed-input rejections and 3000 mutations.',
  );
}
