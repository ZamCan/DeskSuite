import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/document_scan/camera_gateway.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class FakeCamera implements CameraGateway {
  FakeCamera({this.lost, this.fail = false});
  final Uint8List? lost;
  final bool fail;
  @override
  Future<Uint8List?> capture() async => null;
  @override
  Future<Uint8List?> retrieveLostCapture() async {
    if (fail) throw StateError('private platform error');
    return lost;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'camera data is signature-checked and limited even if reported size lies',
    () async {
      final valid = Uint8List.fromList(
        img.encodePng(img.Image(width: 2, height: 2)),
      );
      expect(
        await readCapturedImage(XFile.fromData(valid)),
        orderedEquals(valid),
      );
      await expectLater(
        readCapturedImage(XFile.fromData(Uint8List(0))),
        throwsFormatException,
      );
      await expectLater(
        readCapturedImage(XFile.fromData(Uint8List.fromList([1, 2, 3]))),
        throwsFormatException,
      );
      await expectLater(
        readCapturedImage(XFile.fromData(valid, length: valid.length + 1)),
        throwsFormatException,
      );
      await expectLater(
        readCapturedImage(XFile.fromData(Uint8List(maxPhotoInputBytes + 1))),
        throwsFormatException,
      );
      await expectLater(
        readCapturedImage(
          XFile.fromData(Uint8List(maxPhotoInputBytes + 1), length: 1),
        ),
        throwsFormatException,
      );
    },
  );

  test('native originals remain in private cache until draft acknowledgement', () async {
    final root = await Directory.systemTemp.createTemp(
      'desksuite-camera-test-',
    );
    final cache = Directory('${root.path}/cache');
    final outside = Directory('${root.path}/elsewhere');
    await cache.create();
    await outside.create();
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const cameraChannel = MethodChannel('com.zamcan.desksuite/document_camera');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (call) async => cache.path);
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));
    final source = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 2, height: 2)),
    );
    final file = File('${cache.path}/desksuite-capture-test-123.jpg');
    await file.writeAsBytes(source);
    messenger.setMockMethodCallHandler(
      cameraChannel,
      (call) async => file.path,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(cameraChannel, null));

    final gateway = AndroidCameraGateway();
    expect(await gateway.capture(), orderedEquals(source));
    expect(
      await file.exists(),
      isTrue,
      reason: 'reading alone is not a durable draft',
    );
    // A new gateway can recover an interrupted capture before acknowledgement.
    final restarted = AndroidCameraGateway();
    expect(await restarted.retrieveLostCapture(), orderedEquals(source));
    expect(await file.exists(), isTrue);
    await restarted.acknowledgeCaptureSaved();
    expect(await file.exists(), isFalse);

    // A process can die after writing but before the atomic rename.
    final interrupted = File('${cache.path}/desksuite-writing-123.tmp');
    await interrupted.writeAsBytes(source);
    final interruptedGateway = AndroidCameraGateway();
    expect(
      await interruptedGateway.retrieveLostCapture(),
      orderedEquals(source),
    );
    expect(await interrupted.exists(), isTrue);
    expect(await interruptedGateway.discardPendingCapture(), isTrue);
    expect(await interrupted.exists(), isFalse);

    final wrongPlace = File('${outside.path}/desksuite-capture-test-456.jpg');
    await wrongPlace.writeAsBytes(source);
    messenger.setMockMethodCallHandler(
      cameraChannel,
      (call) async => wrongPlace.path,
    );
    await expectLater(gateway.capture(), throwsFormatException);
    expect(
      await wrongPlace.exists(),
      isTrue,
      reason: 'untrusted paths are never deleted',
    );
  });

  test(
    'startup recovery returns real bytes or a safe failure without details',
    () async {
      final data = Uint8List.fromList([9, 8, 7]);
      expect(
        (await recoverCameraCapture(FakeCamera(lost: data))).bytes,
        same(data),
      );
      final error = await recoverCameraCapture(FakeCamera(fail: true));
      expect(error.failed, isTrue);
      expect(error.bytes, isNull);
      expect((await recoverCameraCapture(null)).failed, isFalse);
    },
  );
}
