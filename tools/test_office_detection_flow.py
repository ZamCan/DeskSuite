#!/usr/bin/env python3
"""Test actual Office detection and package reuse with a fake bounded reader.

Requires an existing Dart SDK, or use --emit to write the harness. This does
not exercise a real ZIP decoder, XML parser, Flutter, or device memory usage.
"""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'lib/office/office_format.dart').read_text()
source = re.sub(r'^import\s+[^;]+;\s*', '', source, flags=re.M)
stubs = r'''
import 'dart:typed_data';
Future<R> compute<Q, R>(R Function(Q) callback, Q value) async => callback(value);
int opens = 0;
OfficePackage? lastPackage;
class OfficePackage {
  OfficePackage(this.parts);
  final Map<String, String> parts;
  static OfficePackage open(Uint8List bytes) {
    opens++;
    if (bytes.length < 5) throw const FormatException('bad package');
    final part = switch (bytes[4]) {
      1 => 'word/document.xml',
      2 => 'xl/workbook.xml',
      3 => 'ppt/presentation.xml',
      _ => 'other',
    };
    return lastPackage = OfficePackage({part: '<xml/>'});
  }
  bool contains(String name) => parts.containsKey(name);
  String? textOf(String name) => parts[name];
}
'''
main = r'''
void check(bool condition, String message) { if (!condition) throw StateError(message); }
Uint8List zip(int kind) => Uint8List.fromList([0x50, 0x4b, 3, 4, kind]);
Future<void> main() async {
  opens = 0;
  final first = inspectOfficeFile(zip(1), fileName: 'misleading.xlsx');
  check(first.detected.format == OfficeFormat.docx, 'content-based format');
  check(opens == 1 && identical(first.package, lastPackage), 'one retained package');
  final second = detectOfficeFile(zip(2));
  check(second.format == OfficeFormat.xlsx && opens == 2, 'ordinary detection');
  final background = await detectOfficeFileInBackground(zip(3));
  check(background.format == OfficeFormat.pptx && opens == 3, 'background adapter');
  final text = inspectOfficeFile(Uint8List.fromList('hello'.codeUnits));
  check(text.detected.format == OfficeFormat.txt && text.package == null && opens == 3,
      'non-ZIP does not inflate');
  final ole = Uint8List.fromList([0xd0,0xcf,0x11,0xe0,0xa1,0xb1,0x1a,0xe1]);
  check(detectOfficeFile(ole, fileName: 'protected.docx').format == OfficeFormat.ole,
      'ambiguous OLE subtype');
  try { inspectOfficeFile(Uint8List.fromList([0x50,0x4b,3,4])); throw StateError('bad accepted'); }
  on FormatException { }
  try { inspectOfficeFile(zip(4)); throw StateError('unsupported accepted'); }
  on FormatException { }
  print('Actual Office detection/package reuse passed with a fake package reader.');
}
'''
harness = stubs + source + main
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--emit', type=Path)
args = parser.parse_args()
if args.emit:
    args.emit.parent.mkdir(parents=True, exist_ok=True)
    args.emit.write_text(harness)
    print(f'Wrote {args.emit}')
else:
    dart = shutil.which('dart')
    if not dart:
        parser.exit(1, 'No Dart SDK in PATH; use --emit to inspect the harness.\n')
    with tempfile.TemporaryDirectory(prefix='desksuite-office-detect-') as temp:
        target = Path(temp) / 'office_detection_smoke.dart'
        target.write_text(harness)
        subprocess.run([dart, str(target)], check=True)
