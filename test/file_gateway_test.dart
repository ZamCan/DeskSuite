import 'dart:typed_data';

import 'package:desksuite/workspace/file_gateway.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

final class StubFile extends PlatformFile {
  StubFile(this.knownLength, this.chunks);
  final int? knownLength;
  final List<Uint8List> chunks;
  @override
  int? lengthSync() => knownLength;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.fromIterable(chunks);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubPicker extends FilePickerPlatform {
  PlatformFile? result;
  Uri? savedUri;
  String? savedName, savedMimeType;
  Uint8List? savedBytes;
  List<String>? extensions;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    extensions = allowedExtensions;
    return result;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedName = fileName;
    savedBytes = bytes;
    savedMimeType = mimeType;
    return savedUri;
  }
}

void main() {
  late StubPicker picker;
  setUp(() {
    picker = StubPicker();
    FilePickerPlatform.instance = picker;
  });

  test(
    'bounded picker streams local files and accepts both project extensions',
    () async {
      picker.result = StubFile(3, [
        Uint8List.fromList([1, 2, 3]),
      ]);
      expect(await NativeFileGateway().pickProject(), orderedEquals([1, 2, 3]));
      expect(picker.extensions, containsAll(['dsdesign', 'dsproject']));
    },
  );

  test('rejects excessive or empty input and honours cancellation', () async {
    final gateway = NativeFileGateway();
    picker.result = StubFile(9 * 1024 * 1024, []);
    await expectLater(gateway.pickImage(), throwsFormatException);
    picker.result = StubFile(null, [
      Uint8List(5 * 1024 * 1024),
      Uint8List(4 * 1024 * 1024),
    ]);
    await expectLater(gateway.pickImage(), throwsFormatException);
    picker.result = StubFile(0, []);
    await expectLater(gateway.pickImage(), throwsFormatException);
    picker.result = null;
    expect(await gateway.pickImage(), isNull);
  });

  test(
    'exports supplied bytes with MIME type and reports cancellation',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final gateway = NativeFileGateway();
      picker.savedUri = Uri.parse('content://selected/file');
      expect(
        await gateway.save(
          name: 'poster.pdf',
          bytes: bytes,
          mimeType: 'application/pdf',
        ),
        isTrue,
      );
      expect(picker.savedName, 'poster.pdf');
      expect(picker.savedMimeType, 'application/pdf');
      expect(picker.savedBytes, bytes);
      picker.savedUri = null;
      expect(
        await gateway.save(
          name: 'poster.png',
          bytes: bytes,
          mimeType: 'image/png',
        ),
        isFalse,
      );
      await expectLater(
        gateway.save(
          name: '../escape.pdf',
          bytes: bytes,
          mimeType: 'application/pdf',
        ),
        throwsFormatException,
      );
    },
  );
}
