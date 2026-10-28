# Image optimisation and export

## Implemented in the current source

Photo Studio has an **Optimise & export** workflow implemented in `lib/images/image_optimizer.dart` and integrated into `lib/legacy_studios.dart`.

- **Dimensions:** original, 120×150, 300×300, 300×400, 600×600, 600×800, 1200×1500, and custom width/height in pixels.
- **Aspect ratio:** preserved by default. A user can explicitly turn it off when exact dimensions matter more than proportions. With preservation enabled, the result fits inside the selected box and may have smaller dimensions.
- **Compression modes:** choose JPEG quality; request a percentage reduction relative to the current working image bytes; or target a file size in KB.
- **Quality strategy:** for byte targets, lower JPEG quality before gradually reducing resolution, including for very wide or tall images. Each resolution attempt is calculated from the initial target dimensions and sampled from the same opaque source instead of repeatedly resizing the preceding lossy raster. The long side is bounded to a 64 px floor for automatic shrinking, subject to at most 24 dimension steps. The app reports actual output bytes, dimensions, quality and measured reduction. A target is rejected if it cannot be reached within safety limits; output is not promised to match a target exactly.
- **Preservation:** optimisation works on a new copy. It does not overwrite the source image.
- **Export types:** JPEG, an image-only A4 PDF (portrait or landscape, 10 mm margins), and a standalone HTML page embedding the JPEG for offline viewing. The PDF contains no OCR text or encryption and does not promise a specific finished photo size.
- **Bounds:** an external pick is limited to 8 MiB, while an already-edited internal working image can be up to 16 MiB. Decoded and optimized images are limited to 8192 pixels per side and 12 megapixels. Device memory may be more restrictive.

## Security boundary

The current PDF export is **not encrypted**. It must not be described as password- or PIN-protected. The current HTML export embeds the image directly and is also not access-controlled; adding a PIN prompt without encrypting or controlling access to the underlying image would be cosmetic and unsafe. Secured PDF/PIN export remains a separate engineering gate: select a maintained encryption implementation, verify its algorithm and compatibility, test that wrong credentials cannot open the document, and test that correct credentials can. Do not implement a home-grown cryptographic format.

## Standards and product distinctions

- Pixel dimensions are not physical print dimensions. Physical size requires a separately chosen print size and resolution/DPI; this feature does not certify passport or identity-photo compliance.
- Compression percentage means a target reduction in encoded bytes relative to the **current working image**, which may already have been edited or re-encoded, not necessarily the originally selected file. It is not a percentage of image pixels or a guaranteed exact result.
- JPEG is lossy and does not preserve transparency. Transparency is composited onto white before resizing/encoding. Review the output and measured size before saving. The optimizer uses a new RGB raster rather than intentionally copying input metadata, but metadata removal has not been independently verified across all formats; inspect outputs before sharing sensitive images.
- Keep original files available for reset/re-export and never silently replace them.

## Validation still required

Regression tests for pixel presets, custom-dimension validation, alpha-on-white, one EXIF description, >8 MiB working PNGs, JPEG decodability, very wide image byte-target shrinking, A4 PDF page size and source-byte preservation have been written but **not run in Flutter for this branch**. A standalone geometry smoke passed 2,000 randomized sequences under DartPad DDC/Node. A DartPad/Node check exercised optimizer control flow with a simulated codec, not the real image/PDF packages. The integrated Flutter analyzer, complete test suite, independent PDF/image inspection and real-device memory/quality checks must pass before calling the feature release-ready.
