#!/usr/bin/env python3
"""Exercise the actual PDF combine and inspection control flow with fake parsers.

An existing Dart SDK is required; --emit only writes the standalone harness.
This does not validate real PDF parsing, merger output, Flutter or devices.
The harness reduces the aggregate input budget to make that branch inexpensive.
"""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
limits = (ROOT / 'lib/core/file_limits.dart').read_text()
inspection = (ROOT / 'lib/pdf/pdf_inspection.dart').read_text()
combine = (ROOT / 'lib/pdf/pdf_combine.dart').read_text()
inspection = re.sub(r'^import\s+[^;]+;\s*', '', inspection, flags=re.M)
combine = re.sub(r'^import\s+[^;]+;\s*', '', combine, flags=re.M)
combine = combine.replace('const int maxPdfCombineBytes = maxPdfBytes;',
                          'const int maxPdfCombineBytes = 64;')
stubs = r'''
import 'dart:typed_data';
Future<R> compute<Q, R>(R Function(Q) callback, Q value) async => callback(value);
Uint8List fakePdf(int pages, {int flags = 0, int size = 8}) {
  final b = Uint8List(size < 8 ? 8 : size);
  b.setRange(0, 5, '%PDF-'.codeUnits);
  b[5] = pages;
  b[6] = flags;
  return b;
}
class _Cos { _Cos(this.isEncrypted); final bool isEncrypted; }
class _Box { double get width => 595; double get height => 842; }
class _Page { _Box get cropBox => _Box(); }
class PdfDocument {
  PdfDocument(this.bytes);
  final Uint8List bytes;
  static PdfDocument open(Uint8List bytes, {String password = ''}) {
    if (bytes[6] == 2) throw StateError('password required');
    return PdfDocument(bytes);
  }
  int get pageCount {
    if (bytes[6] == 3) throw StateError('damaged page tree');
    return bytes[5];
  }
  _Cos get cos => _Cos(bytes[6] == 1);
  _Page page(int index) => _Page();
}
class PdfMerger {
  static bool wrongCount = false;
  static bool throwFailure = false;
  static Uint8List merge(List<Uint8List> sources) {
    if (throwFailure) throw StateError('broken merge');
    final count = sources.fold<int>(0, (sum, source) => sum + source[5]);
    return fakePdf(count + (wrongCount ? 1 : 0));
  }
}
'''
main = r'''
void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
void reject(List<Uint8List> files, String expected) {
  try { combinePdfs(files); } on PdfCombineFailure catch (e) {
    check(e.message.toLowerCase().contains(expected.toLowerCase()), expected);
    return;
  }
  throw StateError('Expected rejection: $expected');
}
Future<void> main() async {
  final first = fakePdf(2), second = fakePdf(3);
  final original = Uint8List.fromList(first);
  final result = combinePdfs([first, second]);
  check(result.documentCount == 2 && result.pageCount == 5, 'ordered counts');
  check(result.sourcePageCounts[0] == 2 && result.sourcePageCounts[1] == 3, 'order');
  check(first.toString() == original.toString(), 'source modified');
  final background = await combinePdfsInBackground([first, second]);
  check(background.pageCount == 5, 'background adapter');
  check(combinedPdfName('/tmp/My Report.pdf') == 'My-Report-combined.pdf', 'safe name');
  reject([first], 'at least two');
  reject(List.generate(11, (_) => fakePdf(1)), 'no more than 10');
  reject([fakePdf(1, size: 33), fakePdf(1, size: 33)], 'combined working limit');
  reject([first, fakePdf(1, flags: 1)], 'encrypted');
  reject([first, fakePdf(1, flags: 2)], 'password');
  reject([first, fakePdf(0)], 'no pages');
  PdfMerger.wrongCount = true;
  reject([first, second], 'produced');
  PdfMerger.wrongCount = false;
  PdfMerger.throwFailure = true;
  reject([first, second], 'could not be combined');
  print('Actual PDF combine/inspection control flow passed with fake parser and merger.');
}
'''
harness = stubs + limits + inspection + combine + main
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
    with tempfile.TemporaryDirectory(prefix='desksuite-pdf-combine-') as temp:
        target = Path(temp) / 'pdf_combine_smoke.dart'
        target.write_text(harness)
        subprocess.run([dart, str(target)], check=True)
