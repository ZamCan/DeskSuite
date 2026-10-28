#!/usr/bin/env python3
"""Exercise the actual unchanged-template save handler against a fake gateway.

Requires an existing Dart SDK; --emit path.dart only writes the harness. This
is a control-flow test, not a native save-picker or Office compatibility test.
"""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'lib/office/office_convert_page.dart').read_text()
method = source[source.index('  Future<void> _saveOriginalTemplate()'):source.index('  Future<void> _convert()')]
catalog = (root / 'lib/office/office_template_catalog.dart').read_text()
stubs = r'''
class FakeFiles {
  String? name, mime;
  Uint8List? bytes;
  bool result = true, throws = false;
  int calls = 0;
  Completer<bool>? gate;
  Future<bool> save({required String name, required Uint8List bytes, required String mimeType}) async {
    this.name = name; this.bytes = Uint8List.fromList(bytes); mime = mimeType; calls++;
    if (throws) throw StateError('fake failure');
    if (gate != null) return gate!.future;
    return result;
  }
}
class FakeWidget { FakeWidget(this.files); final FakeFiles files; }
class Harness {
  Harness(this._template, this._source, FakeFiles files) : widget = FakeWidget(files);
  final FakeWidget widget;
  OfficeTemplateDefinition? _template;
  Uint8List? _source;
  Object? _detected = Object();
  bool _busy = false, mounted = true;
  String? _error, _status;
  void setState(void Function() fn) => fn();
'''
main = r'''
}
void check(bool value, String message) { if (!value) throw StateError(message); }
Future<void> main() async {
  check(officeTemplateCatalog.length == 6, 'catalog size');
  for (final item in officeTemplateCatalog) {
    final bytes = Uint8List.fromList([80, 75, 3, 4, item.fileName.length]);
    final files = FakeFiles();
    final h = Harness(item, bytes, files);
    await h._saveOriginalTemplate();
    check(files.name == 'copy-${item.fileName}' && files.mime == item.mimeType, 'name/MIME');
    check(files.bytes!.join(',') == bytes.join(','), 'bytes changed');
    check(h._status!.contains('unchanged') && !h._busy, 'success state');
  }
  final item = officeTemplateCatalog.first;
  final bytes = Uint8List.fromList([1,2,3]);
  final cancelledFiles = FakeFiles()..result = false;
  final cancelled = Harness(item, bytes, cancelledFiles);
  await cancelled._saveOriginalTemplate();
  check(cancelled._status!.contains('cancelled') && !cancelled._busy, 'cancellation');
  final failedFiles = FakeFiles()..throws = true;
  final failed = Harness(item, bytes, failedFiles);
  await failed._saveOriginalTemplate();
  check(failed._error!.contains('Could not save') && !failed._busy, 'error');
  final files = FakeFiles()..gate = Completer<bool>();
  final running = Harness(item, bytes, files);
  final pending = running._saveOriginalTemplate();
  check(running._busy && files.calls == 1, 'busy while waiting');
  await running._saveOriginalTemplate();
  check(files.calls == 1, 'concurrent save');
  files.gate!.complete(true);
  await pending;
  check(!running._busy, 'busy after completion');
  final noSourceFiles = FakeFiles();
  final noSource = Harness(item, null, noSourceFiles);
  await noSource._saveOriginalTemplate();
  check(noSourceFiles.calls == 0, 'missing source saved');
  print('Actual Office original-template save handler passed with a fake gateway.');
}
'''
harness = "import 'dart:async';\nimport 'dart:typed_data';\n" + catalog + stubs + method + main
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
    with tempfile.TemporaryDirectory(prefix='desksuite-office-template-') as temp:
        target = Path(temp) / 'office_template_save_smoke.dart'
        target.write_text(harness)
        subprocess.run([dart, str(target)], check=True)
