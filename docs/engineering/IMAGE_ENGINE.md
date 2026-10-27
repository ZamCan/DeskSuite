# Local image engine — first implementation

`lib/image_engine/image_processing_service.dart` adds deterministic local image inspection, resize, crop, 90-degree-step rotation and PNG/JPEG/BMP/GIF encoding. It checks byte and pixel limits, validates crop coordinates, returns source/output metadata and decodes the encoded result to verify dimensions. It never writes over source files.

This is a processing service, not yet a connected Photo Studio screen. Operations are currently synchronous and must be moved off the UI isolate for large images before UI integration. EXIF preservation, color-managed printing, background removal, perspective correction, passport photo presets and animated GIF preservation are not claimed. The default decoded-pixel safety limit is 40 megapixels.

Automated tests cover exact resize, aspect-preserving resize, crop bounds, rotation dimensions, malformed input and output decoding. CI must run `flutter pub get`, `dart format lib test`, `flutter analyze` and `flutter test` before this stage is accepted.