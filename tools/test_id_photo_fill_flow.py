#!/usr/bin/env python3
"""Exercise actual ID photo-fill control flow with fake picker/image decoder.

Requires an existing Dart SDK. --emit path.dart writes the standalone harness.
It does not test Flutter's real decoder, platform picker, rendering or devices.
"""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]


def strip(path):
    text = (root / path).read_text()
    return re.sub(r"^import\s+['\"][^'\"]+['\"](?:\s+as\s+\w+)?;\s*", '', text, flags=re.M)


source = (root / 'lib/design/editor_screen.dart').read_text()
method = source[source.index('  Future<void> _fillPhotoSlot()'):source.index('  Future<void> _editText()')]
stubs = r'''
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
int nextId = 0;
String newId() => 'd_${nextId++}';
bool isSafeId(String id) => RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id);
class ChangeNotifier { void notifyListeners() {} void dispose() {} }
class Offset {
  const Offset(this.dx, this.dy); final double dx, dy;
  static const zero = Offset(0, 0);
  Offset operator +(Offset other) => Offset(dx + other.dx, dy + other.dy);
  Offset operator -(Offset other) => Offset(dx - other.dx, dy - other.dy);
  double get distance => math.sqrt(dx*dx + dy*dy);
}
'''
model = ''.join(strip(p) for p in [
    'lib/core/physical_page_limits.dart', 'lib/design/design_document.dart',
    'lib/design/geometry.dart', 'lib/design/design_controller.dart',
])
fakes = r'''
class FakeFiles {
  Uint8List? result;
  Completer<Uint8List?>? gate;
  Future<Uint8List?> pickImage() async => gate == null ? result : gate!.future;
}
class FakeWidget { FakeWidget(this.files); final FakeFiles files; }
class FakeImages {
  int syncs = 0;
  Future<void> sync(DesignDocument doc) async {
    syncs++;
    if (doc.elements.length > maxDesignElements) throw StateError('too many layers');
    final image = doc.elements.singleWhere((e) => e.kind == ElementKind.image);
    if (image.imageBytes!.first == 0) throw const FormatException('bad image');
  }
}
class Harness {
  Harness(this._controller, FakeFiles files) : widget = FakeWidget(files);
  final DesignController _controller;
  final FakeWidget widget;
  final FakeImages _images = FakeImages();
  Future<void> _imageSync = Future.value();
  bool mounted = true, _busy = false;
  String? message;
  void setState(void Function() fn) => fn();
  void _message(String value) => message = value;
'''
main = r'''
}
void check(bool value, String message) { if (!value) throw StateError(message); }
DesignDocument sample() {
  final slot = DesignElement(id: 'slot', kind: ElementKind.rectangle, x: 5, y: 5, width: 20, height: 30, text: photoPlaceholderMarker, rotation: 15, opacity: .8);
  final extras = List.generate(99, (i) => DesignElement(id:'ordinary-$i', kind:ElementKind.rectangle, x:0, y:0, width:1, height:1));
  return DesignDocument.blank(name:'test',widthMm:100,heightMm:100).copyWith(elements:[slot, ...extras]);
}
Future<void> main() async {
  final original = sample();
  final controller = DesignController(original)..select('slot');
  final files = FakeFiles()..result = Uint8List.fromList([1,2,3]);
  final h = Harness(controller, files);
  await h._fillPhotoSlot();
  check(h.message == null && !h._busy && h._images.syncs == 1, 'valid fill');
  check(controller.document.elements.length == 100, 'layer-limit fill');
  final image = controller.document.elements.singleWhere((e)=>e.kind==ElementKind.image);
  check(image.rotation == 15 && image.opacity == .8, 'slot transform');
  controller.undo();
  check(controller.document.elements.any((e)=>e.id=='slot'), 'undo');

  final invalidController = DesignController(original)..select('slot');
  final invalid = Harness(invalidController, FakeFiles()..result=Uint8List.fromList([0]));
  await invalid._fillPhotoSlot();
  check(invalidController.document.elements.any((e)=>e.id=='slot') && invalid.message!.contains('bad image'), 'invalid image changed project');

  final changingController = DesignController(original)..select('slot');
  final changingFiles = FakeFiles()..gate = Completer<Uint8List?>();
  final changing = Harness(changingController, changingFiles);
  final pending = changing._fillPhotoSlot();
  changingController.select('ordinary-0');
  changingFiles.gate!.complete(Uint8List.fromList([1]));
  await pending;
  check(changingController.document.elements.any((e)=>e.id=='slot') && changing._images.syncs == 0, 'changed selection mutated project');
  check(changing.message!.contains('select it again') && !changing._busy, 'selection change notice');
  print('Actual ID photo-fill method passed with fake picker/decoder, including layer limit, bad image and selection race.');
}
'''
harness = stubs + model + fakes + method + main
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
    with tempfile.TemporaryDirectory(prefix='desksuite-id-fill-') as temp:
        target = Path(temp) / 'id_fill_smoke.dart'
        target.write_text(harness)
        subprocess.run([dart, str(target)], check=True)
