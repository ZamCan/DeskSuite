import 'dart:convert';
import 'dart:typed_data';

/// Metadata validated before the ZIP library is allowed to inflate any entry.
class OfficeZipEntry {
  const OfficeZipEntry({required this.size, required this.crc32});

  final int size;
  final int crc32;
}

/// Validate a bounded, single-disk office ZIP before parsing it.
///
/// The ZIP library may inspect Unix symlinks while decoding, before returning
/// an entry to its caller. Reject those and oversized declarations first. The
/// supported office ZIPs use stored or deflated entries. ZIP64, encryption,
/// multi-disk files, duplicate names, inconsistent headers and overlapping
/// payloads fail closed. These deliberate restrictions are not a general ZIP
/// implementation.
Map<String, OfficeZipEntry> guardOfficeZip(
  Uint8List bytes, {
  required int maxEntries,
  required int maxEntryBytes,
  required int maxTotalBytes,
}) {
  const invalid = FormatException(
    'The document package is damaged or unsupported.',
  );
  if (bytes.length < 22 ||
      maxEntries < 1 ||
      maxEntryBytes < 0 ||
      maxTotalBytes < 0) {
    throw invalid;
  }
  final data = ByteData.sublistView(bytes);
  int u16(int offset) => data.getUint16(offset, Endian.little);
  int u32(int offset) => data.getUint32(offset, Endian.little);

  // The EOCD can be followed only by its 16-bit-length comment. Searching a
  // maximum of 65,557 bytes also avoids treating a nested ZIP as the directory.
  final lower = (bytes.length - 22 - 65535).clamp(0, bytes.length);
  var eocd = -1;
  for (var offset = bytes.length - 22; offset >= lower; offset--) {
    if (u32(offset) == 0x06054b50 &&
        offset + 22 + u16(offset + 20) == bytes.length) {
      eocd = offset;
      break;
    }
  }
  if (eocd < 0 || (eocd >= 20 && u32(eocd - 20) == 0x07064b50)) {
    throw invalid; // Missing directory or ZIP64 locator.
  }
  final disk = u16(eocd + 4);
  final directoryDisk = u16(eocd + 6);
  final diskEntries = u16(eocd + 8);
  final entryCount = u16(eocd + 10);
  final directorySize = u32(eocd + 12);
  final directoryOffset = u32(eocd + 16);
  if (disk != 0 ||
      directoryDisk != 0 ||
      diskEntries != entryCount ||
      entryCount == 0xffff ||
      directorySize == 0xffffffff ||
      directoryOffset == 0xffffffff ||
      directoryOffset + directorySize != eocd) {
    throw invalid;
  }
  if (entryCount == 0) {
    throw const FormatException('The document package contains no parts.');
  }
  if (entryCount > maxEntries) {
    throw const FormatException('The document contains too many parts.');
  }

  final result = <String, OfficeZipEntry>{};
  final payloads = <({int start, int end})>[];
  var cursor = directoryOffset;
  var expanded = 0;
  for (var i = 0; i < entryCount; i++) {
    if (cursor < 0 || cursor + 46 > eocd || u32(cursor) != 0x02014b50) {
      throw invalid;
    }
    final madeBy = u16(cursor + 4) >> 8;
    final flags = u16(cursor + 8);
    final method = u16(cursor + 10);
    final crc = u32(cursor + 16);
    final compressed = u32(cursor + 20);
    final uncompressed = u32(cursor + 24);
    final nameLength = u16(cursor + 28);
    final extraLength = u16(cursor + 30);
    final commentLength = u16(cursor + 32);
    final diskStart = u16(cursor + 34);
    final attributes = u32(cursor + 38);
    final localOffset = u32(cursor + 42);
    final next = cursor + 46 + nameLength + extraLength + commentLength;
    if (next > eocd ||
        nameLength == 0 ||
        diskStart != 0 ||
        compressed == 0xffffffff ||
        uncompressed == 0xffffffff ||
        localOffset == 0xffffffff ||
        (flags & 0x41) != 0 ||
        (method != 0 && method != 8) ||
        (madeBy == 3 && ((attributes >> 16) & 0xf000) == 0xa000)) {
      throw invalid;
    }
    if (uncompressed > maxEntryBytes) {
      throw const FormatException('A document part exceeds the 24 MB limit.');
    }
    expanded += uncompressed;
    if (expanded > maxTotalBytes) {
      throw const FormatException(
        'The document expands beyond the 64 MB processing limit.',
      );
    }
    if (method == 0 && compressed != uncompressed) throw invalid;

    final rawName = bytes.sublist(cursor + 46, cursor + 46 + nameLength);
    if (rawName.contains(0)) throw invalid;
    String name;
    try {
      name = utf8.decode(rawName);
    } on FormatException {
      // Match archive's fallback for old non-UTF-8 ZIP filenames.
      name = String.fromCharCodes(rawName);
    }
    if (result.containsKey(name)) throw invalid;

    if (localOffset + 30 > directoryOffset || u32(localOffset) != 0x04034b50) {
      throw invalid;
    }
    final localFlags = u16(localOffset + 6);
    final localMethod = u16(localOffset + 8);
    final localNameLength = u16(localOffset + 26);
    final localExtraLength = u16(localOffset + 28);
    final dataStart = localOffset + 30 + localNameLength + localExtraLength;
    final dataEnd = dataStart + compressed;
    if (localFlags != flags ||
        localMethod != method ||
        localNameLength != nameLength ||
        dataEnd > directoryOffset ||
        dataStart > directoryOffset) {
      throw invalid;
    }
    for (var n = 0; n < nameLength; n++) {
      if (bytes[localOffset + 30 + n] != rawName[n]) throw invalid;
    }
    // When bit 3 is set, the actual CRC and sizes are in the central directory
    // and a data descriptor; zero local fields are normal.
    if ((flags & 8) == 0 &&
        (u32(localOffset + 14) != crc ||
            u32(localOffset + 18) != compressed ||
            u32(localOffset + 22) != uncompressed)) {
      throw invalid;
    }
    payloads.add((start: localOffset, end: dataEnd));
    result[name] = OfficeZipEntry(size: uncompressed, crc32: crc);
    cursor = next;
  }
  if (cursor != eocd) throw invalid;
  payloads.sort((a, b) => a.start.compareTo(b.start));
  for (var i = 1; i < payloads.length; i++) {
    if (payloads[i].start < payloads[i - 1].end) throw invalid;
  }
  return result;
}

/// Computes the ZIP CRC-32 for the inflated entry bytes. Archive decoders may
/// parse with a verification flag without reliably rejecting a content/CRC
/// mismatch, so OfficePackage checks this explicitly after bounded inflation.
final List<int> _officeCrcTable = List<int>.generate(256, (value) {
  var crc = value;
  for (var bit = 0; bit < 8; bit++) {
    crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ 0xedb88320;
  }
  return crc & 0xffffffff;
}, growable: false);

int officeZipCrc32(Uint8List bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc = _officeCrcTable[(crc ^ byte) & 0xff] ^ (crc >> 8);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
