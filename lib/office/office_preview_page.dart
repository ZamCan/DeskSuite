import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;

import 'office_format.dart';

/// Deliberately opt-in until Android device isolation, fidelity and
/// accessibility have been verified. This does not enable conversions.
const officePreviewEnabled = bool.fromEnvironment(
  'DESKSUITE_EXPERIMENTAL_OFFICE_PREVIEW',
  defaultValue: false,
);
const officePreviewMaxBytes = 8 * 1024 * 1024;

bool get officePreviewPlatformSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool canPreviewOfficeFormat(OfficeFormat format) =>
    format.isOpenXml || format.isOpenDocument || format.isOfficeCompound;

/// Android hosts the real C++ engine compiled to WebAssembly inside an
/// isolated local-only WebView. It is only the document surface, not the app.
class OfficePreviewPage extends StatelessWidget {
  const OfficePreviewPage({
    super.key,
    required this.source,
    required this.sourceName,
  });

  final Uint8List source;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final available =
        officePreviewPlatformSupported &&
        source.isNotEmpty &&
        source.length <= officePreviewMaxBytes;
    return Scaffold(
      appBar: AppBar(title: const Text('Local document preview')),
      body: available
          ? AndroidView(
              key: const Key('office-native-preview'),
              viewType: 'com.zamcan.desksuite/office-preview',
              creationParams: {'bytes': source, 'name': sourceName},
              creationParamsCodec: const StandardMessageCodec(),
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This preview is available on Android for files up to 8 MB.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}
