import 'dart:typed_data';

import 'package:desksuite/document_scan/camera_gateway.dart';
import 'package:desksuite/images/photo_processor.dart';
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
