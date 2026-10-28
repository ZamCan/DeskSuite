# Image optimisation and export

## Implemented in the current source

Photo Studio has an **Optimise & export** workflow implemented in `lib/images/image_optimizer.dart` and integrated into `lib/legacy_studios.dart`.

- **Dimensions:** original, 120×150, 300×300, 300×400, 600×600, 600×800, 1200×1500, and custom width/height in pixels.
- **Aspect ratio:** preserved by default. A user can explicitly turn it off when exact dimensions matter more than proportions. With preservation enabled, the result fits inside the selected box and may have smaller dimensions.
- **Compression modes:** choose JPEG quality; request a percentage reduction from source bytes; or target a file size in KB.
- **Quality strategy:** for byte targets, lower JPEG quality before gradually reducing resolution. The app reports actual output bytes, dimensions, quality and measured reduction. A target is rejected if it cannot be reached within safety limits; output is not promised to match a target exactly.
- **Preservation:** optimisation works on a new copy. Choose a different destination to avoid overwriting the source image; the platform save dialog may permit replacement.
- **Export types:** JPEG, an image-only PDF, and a standalone HTML page embedding the JPEG for offline viewing.
- **Bounds:** source image is limited by the existing 8 MB/12-megapixel image pipeline; output is bounded to 8192 pixels per side and 12 megapixels.

## Security boundary

The current PDF export is **not encrypted**. It must not be described as password- or PIN-protected. The current HTML export embeds the image directly and is also not access-controlled; adding a PIN prompt without encrypting or controlling access to the underlying image would be cosmetic and unsafe. Secured PDF/PIN export remains a separate engineering gate: select a maintained encryption implementation, verify its algorithm and compatibility, test that wrong credentials cannot open the document, and test that correct credentials can. Do not implement a home-grown cryptographic format.

## Standards and product distinctions

- Pixel dimensions are not physical print dimensions. Physical size requires a separately chosen print size and resolution/DPI; this feature does not certify passport or identity-photo compliance.
- Compression percentage means a target reduction in encoded bytes relative to the selected source bytes, not a percentage of image pixels or a guaranteed exact result.
- JPEG is lossy and does not preserve transparency. The output preview and measured size must be reviewed before saving.
- Keep original files available for reset/re-export and never silently replace them.

## Validation still required

Automated tests cover pixel preset resolution, custom-dimension validation, JPEG decodability and source-byte preservation. The integrated Flutter analyzer, complete test suite, platform builds, and real-device memory/quality checks must pass before calling the feature release-ready.
