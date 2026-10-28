#!/usr/bin/env python3
"""Run actual scan sample/capacity control flow with fake UI, codecs and store.

Requires an existing Dart SDK; --emit path.dart only writes the harness. This is
not a Flutter/widget, image-decoder, filesystem, PDF or Android test.
"""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'lib/document_scan/scan_studio_page.dart').read_text()
capacity = source[source.index('  void _checkCapacity('):source.index('  Future<bool> _addBytes(')]
samples = source[source.index('  Future<void> _samples()'):source.index('  Future<void> _edit(')]
stubs = r'''
import 'dart:typed_data';
const int maxScanPages = 8, maxScanTotalPixels = 24000000, maxScanTotalBytes = 32 * 1024 * 1024;
class Key { const Key(String value); }
class Text { const Text(String value); }
class SimpleDialog { SimpleDialog({required Text title, required List<Object> children}); }
class SimpleDialogOption { SimpleDialogOption({Key? key, required void Function() onPressed, required Text child}); }
class Navigator { static void pop(Object context, [Object? value]) {} }
List<String>? dialogResult;
Future<T?> showDialog<T>({required Object context, required Object Function(Object) builder}) async => dialogResult as T?;
class FakeBundle {
  int loads = 0;
  Future<ByteData> load(String path) async {
    loads++;
    return ByteData.sublistView(Uint8List.fromList([loads]));
  }
}
final rootBundle = FakeBundle();
enum PhotoAction { png }
class PhotoRequest { PhotoRequest(this.bytes, this.action); final Uint8List bytes; final PhotoAction action; }
class PhotoResult { PhotoResult(this.bytes, this.width, this.height); final Uint8List bytes; final int width, height; }
int nextId = 0;
class ScanDraftPage {
  ScanDraftPage({required this.original, required this.image}) : id = nextId++;
  final PhotoResult original, image; final int id;
}
class Harness {
  List<ScanDraftPage> pages = [];
  bool busy = false, loading = false, mounted = true;
  final context = Object();
  int selected = 0, processCount = 0, persistCount = 0;
  Object? undoImage, undoId;
  int? failAt;
  int width = 10, height = 10;
  bool persistResult = true;
  String lastMessage = '';
  void setState(void Function() fn) => fn();
  void message(String value) => lastMessage = value;
  String readableError(Object error, String fallback) => error is FormatException ? error.message : fallback;
  Future<PhotoResult> processPhoto(PhotoRequest request) async {
    processCount++;
    if (processCount == failAt) throw const FormatException('simulated bad page');
    return PhotoResult(request.bytes, width, height);
  }
  Future<bool> _persist() async { persistCount++; return persistResult; }
'''
main = r'''
}
void check(bool value, String message) { if (!value) throw StateError(message); }
ScanDraftPage existing() { final image = PhotoResult(Uint8List.fromList([9]), 10, 10); return ScanDraftPage(original: image, image: image); }
Future<void> main() async {
  dialogResult = ['one.png', 'two.png', 'three.png'];
  rootBundle.loads = 0;
  final ok = Harness()..pages = [existing()];
  final firstId = ok.pages.first.id;
  await ok._samples();
  check(ok.pages.length == 4 && ok.pages.first.id == firstId && ok.selected == 1, 'atomic append/order');
  check(ok.processCount == 3 && ok.persistCount == 1 && !ok.busy, 'processing/persistence/busy');

  rootBundle.loads = 0;
  final overflow = Harness()..pages = List.generate(6, (_) => existing());
  final before = overflow.pages.map((p) => p.id).toList();
  await overflow._samples();
  check(overflow.pages.map((p) => p.id).join(',') == before.join(','), 'overflow changed draft');
  check(rootBundle.loads == 0 && overflow.persistCount == 0 && overflow.lastMessage.contains('8-page'), 'count preflight');

  rootBundle.loads = 0;
  final bad = Harness()..pages = [existing()]..failAt = 2;
  final badId = bad.pages.first.id;
  await bad._samples();
  check(bad.pages.length == 1 && bad.pages.first.id == badId && bad.persistCount == 0, 'failed page partly appended');
  check(bad.lastMessage.contains('simulated bad page') && !bad.busy, 'failure message/busy');

  final pixels = Harness()..pages = [existing()]..width = 4000..height = 4000;
  await pixels._samples();
  check(pixels.pages.length == 1 && pixels.persistCount == 0 && pixels.lastMessage.contains('24 megapixels'), 'aggregate pixel bound');

  final unsaved = Harness()..persistResult = false;
  await unsaved._samples();
  check(unsaved.pages.length == 3 && unsaved.persistCount == 1 && unsaved.lastMessage.contains('not saved'), 'unsaved in-memory notice');

  dialogResult = null;
  final cancelled = Harness();
  await cancelled._samples();
  check(cancelled.pages.isEmpty && cancelled.persistCount == 0 && !cancelled.busy, 'cancel');
  print('Actual scan sample and capacity flow passed with fake dialog, assets, codec and store.');
}
'''
harness = stubs + capacity + samples + main
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
    with tempfile.TemporaryDirectory(prefix='desksuite-scan-samples-') as temp:
        target = Path(temp) / 'scan_sample_smoke.dart'
        target.write_text(harness)
        subprocess.run([dart, str(target)], check=True)
