#!/usr/bin/env python3
"""Run the actual PDF split-save flow against a fake parser and file gateway.

Requires an existing Dart SDK. `--emit path.dart` only writes the harness.
This checks control flow, not real PDF parsing, platform pickers or devices.
"""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'lib/pdf/pdf_studio_page.dart').read_text()
start = source.index('  Future<void> _saveSplit(')
end = source.index('\n  Widget _buildCombineCard(', start)
method = source[start:end]
stubs = r'''
import 'dart:async';
import 'dart:typed_data';

// Tiny budget makes the actual aggregate-size branch cheap to exercise.
const int maxPdfBytes = 10;
class PdfOpenFailure implements Exception {
  const PdfOpenFailure(this.message);
  final String message;
}
Future<void> inspectPdfInBackground(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.first != 42) throw const PdfOpenFailure('Invalid PDF');
}
class FakeFiles {
  final names = <String>[];
  final results = <bool>[];
  int? throwsAt;
  Completer<bool>? waitFor;
  Future<bool> save({required String name, required Uint8List bytes, required String mimeType}) async {
    names.add(name);
    if (throwsAt == names.length) throw StateError('simulated write failure');
    if (waitFor != null) { final waiting = waitFor!; waitFor = null; return waiting.future; }
    return results.isEmpty ? true : results.removeAt(0);
  }
}
class FakeWidget { FakeWidget(this.files); final FakeFiles files; }
class Harness {
  Harness(FakeFiles files) : widget = FakeWidget(files);
  final FakeWidget widget;
  String? _sourceName = 'report';
  bool _saving = false, _opening = false, _combining = false;
  bool get _busy => _saving || _opening || _combining;
  bool mounted = true;
  String? _error, _status;
  void setState(void Function() update) => update();
'''
main = r'''
}
void check(bool condition, String message) { if (!condition) throw StateError(message); }
Future<void> main() async {
  Uint8List good() => Uint8List.fromList([42]);
  final emptyFiles = FakeFiles();
  final empty = Harness(emptyFiles);
  await empty._saveSplit([]);
  check(emptyFiles.names.isEmpty && empty._status!.contains('No split files'), 'empty split notice');
  final tooManyFiles = FakeFiles();
  final tooMany = Harness(tooManyFiles);
  await tooMany._saveSplit(List.generate(101, (_) => good()));
  check(tooManyFiles.names.isEmpty && tooMany._error!.contains('100 files'), 'split count bound');
  final largeFiles = FakeFiles();
  final large = Harness(largeFiles);
  await large._saveSplit([Uint8List.fromList([42, 0, 0, 0, 0, 0]), Uint8List.fromList([42, 0, 0, 0, 0, 0])]);
  check(largeFiles.names.isEmpty && large._error!.contains('combined split outputs'), 'aggregate split bound');
  final invalidFiles = FakeFiles();
  final invalid = Harness(invalidFiles);
  await invalid._saveSplit([good(), Uint8List.fromList([1])]);
  check(invalidFiles.names.isEmpty, 'invalid later part must block every save');
  check(invalid._error!.contains('no files were written'), 'invalid error');
  check(!invalid._busy, 'busy cleared after validation failure');

  final cancelledFiles = FakeFiles()..results.addAll([true, false, true]);
  final cancelled = Harness(cancelledFiles);
  await cancelled._saveSplit([good(), good(), good()]);
  check(cancelledFiles.names.length == 2, 'cancellation must stop further prompts');
  check(cancelled._status!.contains('Wrote 1 of 3'), 'partial cancellation count');
  check(!cancelled._busy, 'busy cleared after cancellation');

  final failureFiles = FakeFiles()..throwsAt = 2;
  final failure = Harness(failureFiles);
  await failure._saveSplit([good(), good(), good()]);
  check(failureFiles.names.length == 2, 'failure stops further writes');
  check(failure._error!.contains('after 1 confirmed'), 'failure count');
  check(!failure._busy, 'busy cleared after write failure');

  final successFiles = FakeFiles();
  final success = Harness(successFiles);
  await success._saveSplit([good(), good()]);
  check(successFiles.names.join(',') == 'report-part-1.pdf,report-part-2.pdf', 'names');
  check(success._status!.contains('Split into 2'), 'success');

  final busyFiles = FakeFiles()..waitFor = Completer<bool>();
  final gate = busyFiles.waitFor!;
  final busy = Harness(busyFiles);
  final first = busy._saveSplit([good()]);
  check(busy._busy, 'busy while platform save waits');
  await busy._saveSplit([good()]);
  check(busyFiles.names.length == 1, 'concurrent save ignored');
  gate.complete(true);
  await first;
  check(!busy._busy, 'busy cleared after async completion');
  print('Actual PDF split control flow passed with fake parser and file gateway.');
}
'''
harness = stubs + method + main
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
    with tempfile.TemporaryDirectory(prefix='desksuite-pdf-split-') as temp:
        target = Path(temp) / 'pdf_split_smoke.dart'
        target.write_text(harness)
        subprocess.run([dart, str(target)], check=True)
