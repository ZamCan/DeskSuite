#!/usr/bin/env python3
"""Exercise actual PDF inspection guards with a fake document parser.

Requires an existing Dart SDK; `--emit path.dart` only writes the harness.
This does not validate real PDF parsing, encrypted fixtures or device rendering.
"""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'lib/pdf/pdf_inspection.dart').read_text()
source = re.sub(r'^import\s+[^;]+;\s*', '', source, flags=re.M)
stubs = r'''
import 'dart:typed_data';
bool fakeEncrypted = false;
bool fakePasswordFailure = false;
bool fakePageFailure = false;
bool fakeFirstPageFailure = false;
bool fakeBoxFailure = false;
int fakePageCount = 2;
class _Cos { bool get isEncrypted => fakeEncrypted; }
class _Box { double get width => 595; double get height => 842; }
class _Page {
  _Box get cropBox {
    if (fakeBoxFailure) throw StateError('no usable box');
    return _Box();
  }
}
class PdfDocument {
  static PdfDocument open(Uint8List bytes, {String password = ''}) {
    if (fakePasswordFailure) throw StateError('password required');
    return PdfDocument();
  }
  int get pageCount {
    if (fakePageFailure) throw StateError('internal parser failure');
    return fakePageCount;
  }
  _Cos get cos => _Cos();
  _Page page(int index) {
    if (fakeFirstPageFailure) throw StateError('unreadable first page');
    return _Page();
  }
}
'''
main = r'''
void check(bool condition, String message) { if (!condition) throw StateError(message); }
void main() {
  final bytes = Uint8List.fromList('%PDF-1.7 fake'.codeUnits);
  final report = inspectPdf(bytes);
  check(report.pageCount == 2 && !report.isEncrypted, 'normal report');
  fakeEncrypted = true;
  try { inspectPdf(bytes); throw StateError('encrypted bytes accepted'); }
  on PdfOpenFailure catch (e) { check(e.message.contains('encrypted'), 'encryption refusal'); }
  fakeEncrypted = false; fakePasswordFailure = true;
  try { inspectPdf(bytes); throw StateError('password error accepted'); }
  on PdfOpenFailure catch (e) { check(e.message.contains('password'), 'password refusal'); }
  fakePasswordFailure = false; fakePageFailure = true;
  try { inspectPdf(bytes); throw StateError('bad page tree accepted'); }
  on PdfOpenFailure catch (e) { check(e.message.contains('page information'), 'page failure mapped'); }
  fakePageFailure = false; fakeFirstPageFailure = true;
  try { inspectPdf(bytes); throw StateError('bad first page accepted'); }
  on PdfOpenFailure catch (e) { check(e.message.contains('first PDF page'), 'first page failure mapped'); }
  fakeFirstPageFailure = false; fakeBoxFailure = true;
  check(inspectPdf(bytes).pageSizeLabel == 'Page size not reported', 'unavailable box is tolerated');
  fakeBoxFailure = false; fakePageCount = 0;
  try { inspectPdf(bytes); throw StateError('empty document accepted'); }
  on PdfOpenFailure catch (e) { check(e.message.contains('no pages'), 'zero-page refusal'); }
  try { inspectPdf(Uint8List.fromList('text'.codeUnits)); throw StateError('not PDF accepted'); }
  on PdfOpenFailure catch (e) { check(e.message.contains('not a PDF'), 'signature refusal'); }
  print('Actual PDF inspection guards passed with a fake parser.');
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
        parser.exit(1, 'No Dart SDK in PATH; use --emit to inspect the generated harness.\n')
    with tempfile.TemporaryDirectory(prefix='desksuite-pdf-guard-') as temp:
        target = Path(temp) / 'pdf_guard_smoke.dart'
        target.write_text(harness)
        subprocess.run([dart, str(target)], check=True)
