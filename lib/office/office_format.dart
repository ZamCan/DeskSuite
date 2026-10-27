import 'dart:typed_data';

import 'office_package.dart';

/// Office/package formats DeskSuite can identify from real file content, never
/// from the filename extension alone.
enum OfficeFormat {
  docx('DOCX', 'Word document'),
  xlsx('XLSX', 'Excel workbook'),
  pptx('PPTX', 'PowerPoint presentation'),
  odt('ODT', 'OpenDocument text'),
  ods('ODS', 'OpenDocument spreadsheet'),
  odp('ODP', 'OpenDocument presentation'),
  doc('DOC'),
  xls('XLS'),
  ppt('PPT'),
  rtf('RTF'),
  pdf('PDF'),
  txt('TXT'),
  html('HTML');

  const OfficeFormat(this.label, [this.description = '']);

  final String label;
  final String description;
  bool get isOpenXml =>
      this == OfficeFormat.docx ||
      this == OfficeFormat.xlsx ||
      this == OfficeFormat.pptx;
  bool get isOpenDocument =>
      this == OfficeFormat.odt ||
      this == OfficeFormat.ods ||
      this == OfficeFormat.odp;
  bool get isLegacyBinary =>
      this == OfficeFormat.doc ||
      this == OfficeFormat.xls ||
      this == OfficeFormat.ppt;

  /// Formats this build can read content from.
  bool get isReadable =>
      isOpenXml || isOpenDocument || this == OfficeFormat.rtf;

  /// Formats this build can write. Legacy binary and slide formats are absent
  /// on purpose: a converted copy must never be produced by renaming.
  bool get isWritable =>
      this == OfficeFormat.odt ||
      this == OfficeFormat.ods ||
      this == OfficeFormat.txt ||
      this == OfficeFormat.pdf;
}

class DetectedFile {
  const DetectedFile(this.format, this.detail);
  final OfficeFormat format;

  /// How the format was identified, shown to the user so the detection is not
  /// a black box.
  final String detail;
}

const _zipMagic = [0x50, 0x4b, 0x03, 0x04];

/// Detects the real container type. Throws [FormatException] with an actionable
/// message for unsupported or ambiguous input.
DetectedFile detectOfficeFile(Uint8List bytes, {String? fileName}) {
  if (bytes.isEmpty) {
    throw const FormatException('The selected file is empty.');
  }
  if (_startsWith(bytes, _zipMagic) ||
      _startsWith(bytes, [0x50, 0x4b, 0x05, 0x06])) {
    // A ZIP's parts are compressed, so the container must be opened with the
    // bounded reader before its type can be established honestly.
    return DetectedFile(
      detectPackageFormat(OfficePackage.open(bytes)),
      'ZIP package',
    );
  }
  if (_startsWith(bytes, [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])) {
    // OLE2 compound file: legacy .doc/.xls/.ppt share this container.
    final hint = _extensionOf(fileName);
    final format = switch (hint) {
      'xls' => OfficeFormat.xls,
      'ppt' => OfficeFormat.ppt,
      _ => OfficeFormat.doc,
    };
    return DetectedFile(
      format,
      'Legacy OLE2 compound document — content cannot be read by this build',
    );
  }
  if (_startsWith(bytes, [0x7b, 0x5c, 0x72, 0x74, 0x66])) {
    return const DetectedFile(OfficeFormat.rtf, 'Rich Text Format signature');
  }
  if (_startsWith(bytes, [0x25, 0x50, 0x44, 0x46])) {
    return const DetectedFile(OfficeFormat.pdf, 'PDF signature');
  }
  final text = _decodeLeadingText(bytes);
  if (text != null) {
    final lowered = text.toLowerCase();
    if (lowered.contains('<html') || lowered.contains('<!doctype html')) {
      return const DetectedFile(OfficeFormat.html, 'HTML markup');
    }
    return const DetectedFile(OfficeFormat.txt, 'Plain text content');
  }
  throw const FormatException(
    'This file is not a supported document. DeskSuite reads DOCX, XLSX, PPTX, '
    'ODT, ODS, ODP, RTF, TXT and HTML.',
  );
}

/// Identifies an office format from the parts a package actually contains.
OfficeFormat detectPackageFormat(OfficePackage package) {
  if (package.contains('mimetype')) {
    final mime = (package.textOf('mimetype') ?? '').trim();
    return switch (mime) {
      'application/vnd.oasis.opendocument.text' => OfficeFormat.odt,
      'application/vnd.oasis.opendocument.spreadsheet' => OfficeFormat.ods,
      'application/vnd.oasis.opendocument.presentation' => OfficeFormat.odp,
      _ => throw FormatException(
        'This OpenDocument type ("$mime") is not supported.',
      ),
    };
  }
  if (package.contains('word/document.xml')) return OfficeFormat.docx;
  if (package.contains('xl/workbook.xml')) return OfficeFormat.xlsx;
  if (package.contains('ppt/presentation.xml')) return OfficeFormat.pptx;
  final contentTypes = package.textOf('[Content_Types].xml');
  if (contentTypes != null) {
    if (contentTypes.contains('wordprocessingml.document.main+xml')) {
      return OfficeFormat.docx;
    }
    if (contentTypes.contains('spreadsheetml.sheet.main+xml')) {
      return OfficeFormat.xlsx;
    }
    if (contentTypes.contains('presentationml.presentation.main+xml')) {
      return OfficeFormat.pptx;
    }
  }
  throw const FormatException(
    'This ZIP package is not a supported office document.',
  );
}

String? _decodeLeadingText(Uint8List bytes, {int limit = 512}) {
  final slice = bytes.length > limit ? bytes.sublist(0, limit) : bytes;
  for (final byte in slice) {
    final isText =
        byte == 0x09 ||
        byte == 0x0a ||
        byte == 0x0d ||
        (byte >= 0x20 && byte != 0x7f && byte < 0x80);
    if (!isText) return null;
  }
  return String.fromCharCodes(slice);
}

String _extensionOf(String? fileName) {
  if (fileName == null) return '';
  final dot = fileName.lastIndexOf('.');
  return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}
