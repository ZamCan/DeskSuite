# Local image engine — first implementation

`lib/image_engine/image_processing_service.dart` adds deterministic local image inspection, resize, crop, 90-degree-step rotation and PNG/JPEG/BMP/GIF encoding. It checks byte and pixel limits, validates crop coordinates, returns source/output metadata and decodes the encoded result to verify dimensions. It never writes over source files.

The connected `PhotoStudioScreen` provides image import, preview, metadata, rotate, aspect-preserving resize, reset and export-copy workflows. The connected `PdfStudioScreen` assembles up to 100 imported image pages into a new A4 multi-page PDF, supports page ordering/removal and exports locally. PDF Studio normalizes image pages to PNG before embedding.

These are useful first workflows, not complete replacements for CamScanner, Acrobat, Photoshop or Office. Operations are synchronous and must be moved off the UI isolate for high-resolution workloads. Camera capture, document-edge detection, perspective correction, OCR, searchable PDFs, arbitrary existing-PDF editing, EXIF preservation, color-managed printing, background removal, passport-photo presets and animated GIF preservation are not claimed. The default decoded-pixel safety limit is 40 megapixels; the current file picker caps each imported image at 8 MB.

Automated image-engine tests cover exact resize, aspect-preserving resize, crop bounds, rotation dimensions, malformed input and output decoding. CI must run `flutter pub get`, `dart format lib test`, `flutter analyze` and `flutter test` before this stage is accepted.