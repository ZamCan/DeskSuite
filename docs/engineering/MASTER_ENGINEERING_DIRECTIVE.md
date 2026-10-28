# MASTER ENGINEERING DIRECTIVE — DESKSUITE

**Enterprise Document, Camera, Image, PDF and Productivity Platform**

**Existing Repository Transformation | Production-Oriented Implementation**

**Project:** DeskSuite

**Repository:** https://github.com/ZamCan/DeskSuite

**Product owner and creator:** ZamCan (Mussa Fikiri Ngwegelo)

**Target:** A professional, installable, extensible document-productivity application for Android first, with an architecture prepared for additional platforms.

**Primary objective:** Transform the existing application from its current early-stage implementation into a cohesive, polished, genuinely functional product.

**Operating principle:** Engineer real capabilities, not visual promises.

---

## 1. YOUR ROLE AND RESPONSIBILITY

Act as a coordinated senior engineering organization comprising:

- Principal software architect.
- Senior Android and Flutter engineers.
- Document-processing and PDF-engine engineers.
- Camera, scanning, OCR and image-processing engineers.
- Office-document and conversion engineers.
- UX/UI, accessibility and visual-identity designers.
- Security, privacy and file-integrity engineers.
- QA, automated-testing and release-engineering specialists.
- Product researchers and technical writers.

You may delegate specialized work to other agents where available. Each agent must receive a bounded responsibility, defined interfaces, acceptance criteria and integration requirements.

You retain responsibility for integrating all contributions into one coherent application.

Work directly in the existing DeskSuite online repository. Do not produce only a proposal, demonstration, isolated prototype, design mockup, feature roadmap or disconnected code samples.

Inspect the current codebase, understand its actual capabilities, establish a baseline, and then implement the product transformation through verified repository changes.

Do not ask the product owner to manually repeat information already discoverable in the repository, its commit history, documentation, build configuration or existing application.

If an important technical detail cannot be established, inspect the available evidence first. Ask a question only when a genuine blocking decision cannot reasonably be resolved by a safe engineering default.

## 2. PRODUCT VISION

DeskSuite must become a unified document and productivity workspace that enables users to complete real tasks involving documents, images, scans, PDFs, text, office files and related assets.

Users should be able to arrive with a physical document, photograph, existing file or blank page and leave with a usable result: a cleaned scan, searchable PDF, extracted text, converted document, resized image, compressed file, organized collection or editable document.

The product should compete on workflow completeness, dependable processing, usability, privacy choices, output quality and professional presentation—not on the number of feature names displayed.

Use established products as capability references, including:

- CamScanner-style document capture and scan cleanup.
- Adobe Acrobat-style PDF workflows.
- Microsoft Office-style document editing and formatting.
- LibreOffice-style office-document compatibility and conversion.
- Google Drive-style file access, backup and cross-device continuity.
- Established image tools for resizing, compression, cropping and format conversion.
- OCR and document-understanding tools for extracting readable text and preserving document structure.

These are reference points, not permission to copy proprietary designs, logos, assets, code or undocumented behavior. Create a distinctive ZamCan product identity.

Do not claim parity with these products until specific capabilities have been implemented and tested.

## 3. FIRST ACTION: AUDIT THE EXISTING REPOSITORY

Before making architectural changes, inspect the complete relevant project structure and determine:

1. Current framework, language, minimum Android version and supported target versions.
2. Existing navigation, screens, widgets, design system and responsive behavior.
3. Implemented features versus mockups, placeholders and planned features.
4. Existing document, camera, image, PDF, OCR and conversion dependencies.
5. Existing data models, storage methods, permissions and file-management logic.
6. Existing onboarding, tutorials, sample data and empty states.
7. Current app name, package/application ID, launcher icon, splash screen and branding.
8. Current GitHub Actions workflows and build artifacts.
9. Existing tests, failures, warnings, dependency conflicts and known limitations.
10. Whether the current release APK is signed and whether the repository contains a configured release-signing workflow.
11. The current state of Android compatibility and any existing cross-platform abstractions.
12. License obligations for every major dependency, bundled engine, model and sample asset.

Establish a concise baseline report in the repository, for example:

`docs/engineering/BASELINE_AUDIT.md`

Use an evidence-based capability matrix:

| Capability | Existing state | Required action |
| --- | --- | --- |
| Camera capture | Verified implementation / partial / absent | Improve or implement |
| Document scanning | Verified implementation / partial / absent | Improve or implement |
| OCR and searchable PDFs | Verified implementation / partial / absent | Improve or implement |
| PDF editing and organization | Verified implementation / partial / absent | Improve or implement |
| Image processing | Verified implementation / partial / absent | Improve or implement |
| Office-document support | Verified implementation / partial / absent | Improve or implement |
| File conversion | Verified implementation / partial / absent | Improve or implement |
| Onboarding and tutorials | Verified implementation / partial / absent | Improve or implement |
| App identity and launcher icon | Verified implementation / partial / absent | Improve or implement |
| Cloud integration | Verified implementation / partial / absent | Improve or implement |
| Release build and signing | Verified implementation / partial / absent | Improve or implement |

Never label a feature functional merely because a screen or button exists.

For every capability, record the implementation location, dependencies, tests and known limitations.

Preserve useful existing functionality and working architectural decisions. Avoid unnecessary rewrites.

### Image optimisation and export acceptance gate

Image optimisation must distinguish pixel dimensions, encoded byte size, visual quality, print dimensions/DPI and authority-specific passport/ID rules. Provide preset and custom dimensions plus original-size retention; preserve aspect ratio by default and require an explicit choice before stretching. For target-byte output, reduce JPEG quality first and resample only as needed; report actual dimensions, quality and bytes, preserve the source, and reject impossible targets rather than claim success. Export PDF, HTML and image formats through real encoders. Never call a PDF or HTML PIN-protected unless a reviewed cryptographic/access-control implementation is present and tested. Current image optimiser supports JPEG, PDF and standalone HTML exports; PDF is currently unencrypted and PIN protection is intentionally unavailable pending verified encryption support.

## 4. PRODUCT ARCHITECTURE

Design DeskSuite as one integrated application with clear internal modules and service boundaries.

Suggested logical modules:

- `app_shell`: application initialization, navigation, lifecycle and global state.
- `design_system`: typography, colors, spacing, shapes, elevation, motion and reusable components.
- `onboarding`: first-run education, guided tutorials and sample workspace.
- `camera_capture`: camera lifecycle, focus, exposure, resolution and capture controls.
- `document_scanner`: document detection, perspective correction, crop, enhancement and multipage capture.
- `ocr_engine`: text recognition, layout information, language configuration and confidence handling.
- `pdf_engine`: PDF creation, reading, page manipulation, annotations and export.
- `document_editor`: text and document editing workflows.
- `office_engine`: supported office formats, import, export and conversion.
- `image_engine`: image decoding, resizing, cropping, rotation, compression and format conversion.
- `conversion_engine`: validated conversions between explicitly supported formats.
- `compression_engine`: configurable image, PDF and archive compression where applicable.
- `file_workspace`: file browsing, sorting, search, metadata, rename, move, copy and deletion.
- `sample_library`: bundled tutorial documents and images.
- `cloud_connectors`: optional external storage integrations.
- `security_privacy`: permissions, local data handling, temporary files and secure cleanup.
- `settings`: languages, appearance, defaults, storage and privacy preferences.
- `diagnostics`: structured logs, safe error reporting and performance diagnostics.

These names are architectural suggestions, not a mandate to create a folder for every concept. Follow the existing framework and repository conventions.

Keep the project coherent and maintainable. Avoid scattering duplicate implementations across screens, embedding complex processing directly inside UI widgets, or creating separate competing engines for the same task.

Use well-defined interfaces, reusable processing services, centralized error handling and a consistent result model.

For long-running work, provide progress reporting, cancellation when safe, and recoverable failure states.

## 5. PREMIUM PRODUCT DESIGN AND RESPONSIVE UI

Redesign the complete user experience rather than decorating only the home screen.

The design must feel like a mature productivity product, not a development demo, generic AI application or collection of unrelated cards.

### Visual identity

Create a distinctive visual language combining:

- Refined document-inspired surfaces.
- Carefully controlled glass-like effects where appropriate.
- Clean paper, image and file previews.
- Sophisticated typography and strong hierarchy.
- Professional accent colors and restrained gradients.
- Precise spacing, alignment and iconography.
- Clear primary actions and unobtrusive secondary controls.
- Consistent dialogs, sheets, toolbars, progress states and error messages.

Avoid excessive decoration, emoji-based functional icons, arbitrary gradients, oversized empty cards and dark-blue generic AI styling.

Use meaningful icons from a consistent licensed icon set. Use illustrations only when they explain a workflow or improve orientation.

The design should remain legible and professional in light and dark modes if both are supported.

### Device responsiveness

The application must adapt to real Android screen dimensions, density, font scaling, keyboard visibility, portrait and landscape orientation, and system insets.

Test on compact devices as well as larger screens and tablets where supported.

Prevent:

- Clipped text and buttons.
- Overflowing rows and toolbars.
- Dialogs that extend beyond the display.
- Hidden save/export actions.
- Keyboard overlap with essential controls.
- Unusable camera controls on small screens.
- Broken layouts at larger accessibility font sizes.
- Tiny touch targets or inaccessible contrast.

Prefer flexible layouts and adaptive navigation over hardcoded screen dimensions.

Use suitable minimum touch-target sizes, accessible labels, clear focus states and predictable navigation.

Every important workflow must have deliberate loading, empty, success, partial-success and error states.

## 6. LOGO, APP ICON AND BRAND ASSETS

Create a production-quality DeskSuite identity.

The launcher icon must be a genuine, properly generated asset set suitable for Android—not an emoji, placeholder, text-only rectangle or temporary development icon.

Develop a distinctive combined D + S symbol, visually connected through carefully designed document and image motifs.

The visual concept should communicate:

- Documents and pages.
- Image and scan processing.
- Editing and conversion.
- A unified productivity workspace.

Requirements:

1. Create a polished master logo in vector form where practical.
2. Export a transparent PNG suitable for branding and promotional use.
3. Generate Android launcher icon assets in the appropriate adaptive-icon and legacy formats.
4. Ensure the symbol remains recognizable at small sizes.
5. Use correct safe zones, padding, foreground/background separation and contrast.
6. Ensure the icon matches the in-app visual identity.
7. Replace all applicable default icons, temporary marks and development branding.
8. Verify the generated resources are actually referenced by the application build.
9. Add a splash screen consistent with the product identity.
10. Document how the logo and icon assets can be regenerated.

Delegate professional logo exploration to a design-capable agent if available, but review the result for brand fit and production readiness.

Do not use another company's logo, icon, trademark or visual identity.

## 7. WELCOME EXPERIENCE AND GUIDED TUTORIALS

Build a professional first-run experience that teaches users how to complete real tasks.

Do not make the welcome screen a long promotional presentation. Users should quickly understand what the application can actually do.

The onboarding flow should introduce:

- Scan a paper document.
- Capture and clean a document image.
- Create a multipage PDF.
- Extract text from a scan or image.
- Read, organize and rename documents.
- Convert a supported file.
- Resize or compress an image.
- Edit and export supported documents.
- Save files locally and configure optional cloud storage.

Let users skip onboarding, revisit tutorials later, and enter the workspace without unnecessary registration.

### Interactive tutorial requirement

Tutorials must use actual processing services, not fake success screens.

Bundle a curated, license-compatible set of sample assets, including:

- A sample formal letter.
- A sample invoice or receipt.
- A sample application form.
- A sample academic or business document.
- A sample multipage document.
- A sample photograph.
- A sample document photograph with perspective distortion.
- A sample image with readable text.
- A sample image suitable for resizing and compression.
- A sample editable document in a supported format.

Use fictional information and synthetic identities. Never bundle real users' private documents.

The sample library should include useful examples of formal document dimensions, margins, page sizes, readable text and image-resolution requirements.

Clearly label bundled samples as examples. Do not imply that they are official government, university, banking or legal forms.

Where appropriate, include:

- Original sample.
- Expected processing result.
- Instructions.
- Recommended settings.
- Output preview.
- Explanation of trade-offs.
- A reset or restore option.

For example, an image-resizing tutorial should actually resize the sample image and save an output file. A scanning tutorial should execute the same scan-processing pipeline used by a real user.

A tutorial is complete only when its engine works.

## 8. CAMERA AND INDEPENDENT DOCUMENT SCANNING

Develop a robust document-capture workflow using the device camera.

The camera interface should expose supported controls rather than displaying nonfunctional professional-looking buttons.

Where hardware and platform support permit, implement:

- Camera preview and capture.
- Focus and exposure controls.
- Flash or torch.
- Rear/front camera selection where useful.
- Resolution selection.
- Image orientation handling.
- Edge detection and document boundary guidance.
- Automatic capture where reliable.
- Manual capture and crop fallback.
- Perspective correction.
- Corner adjustment.
- Rotation and straightening.
- Grayscale and black-and-white enhancement.
- Color-document enhancement.
- Shadow reduction where feasible.
- Contrast and sharpness controls.
- Multiple-page scanning.
- Page reordering, replacement and deletion.
- PDF generation.
- Image export.
- OCR integration.
- Retake and undo operations.
- Batch processing with progress indication.

Do not require a network connection for basic capture and scan processing.

Respect actual device hardware capabilities. Do not promise unsupported camera controls.

Use appropriate image-processing algorithms and tested libraries. Keep expensive operations off the UI thread.

Preserve originals until the user confirms the result or chooses an explicit replacement operation.

The scanning workflow should be:

Capture → Detect → Crop → Correct → Enhance → Reorder → OCR if requested → Preview → Export or Save.

Each stage must work independently and provide a manual fallback where automatic processing fails.

## 9. OCR AND TEXT EXTRACTION

Implement a real OCR service for supported languages and image formats.

Evaluate suitable on-device OCR engines, including ML Kit or Tesseract, and select based on accuracy, language availability, licensing, offline capability, package size and maintenance requirements.

Do not integrate multiple engines merely to inflate capabilities.

Required workflows:

- Extract text from camera captures.
- Extract text from existing images.
- Extract text from scanned PDF pages where supported.
- Process multipage documents.
- Display recognized text in an editable view.
- Copy and share extracted text.
- Export extracted text to supported formats.
- Search OCR text where indexing is implemented.
- Display clear feedback when recognition confidence is low.
- Allow correction before export.
- Preserve page and paragraph ordering as far as the engine permits.

Distinguish text extraction from document-layout reconstruction.

If the OCR engine cannot preserve tables, columns, handwriting or complex layouts reliably, state the limitation and provide an appropriate output option.

Support additional languages through a deliberate engine and language-pack strategy. Prioritize languages based on realistic use cases and available models.

Use small language models only where they provide a measurable benefit, such as OCR correction, layout classification or optional text cleanup.

Do not substitute a language model for actual OCR. Never silently change the meaning of extracted text. Any AI-assisted correction must be optional, reviewable and distinguishable from the original OCR output.

## 10. PDF ENGINE

Implement a dependable PDF workspace with clear support boundaries.

Prioritize:

- Open and read PDFs.
- Page navigation and zoom.
- Thumbnail previews.
- Searchable text where available.
- Create PDFs from scans and images.
- Combine supported PDFs.
- Split by selected pages or page ranges.
- Reorder, rotate and delete pages.
- Extract pages.
- Crop pages where supported.
- Add text annotations and highlights where supported.
- Fill supported PDF form fields.
- Signatures or signature images where supported, without claiming cryptographic certificate signing unless implemented.
- Password-protected PDF handling through a secure, supported library.
- Compress PDFs with a preview of quality and size trade-offs.
- Export selected pages as images.
- Add images to supported documents.
- Print or share exported files.
- Recover gracefully from invalid, corrupted or unsupported PDFs.

Clearly distinguish annotations, flattening, editing existing PDF text and reconstructing documents. These are different technical capabilities.

Do not label a PDF as fully editable if the implementation only overlays annotations or converts pages into images.

Preserve page order, dimensions and orientation.

Verify exported PDFs open in independent readers.

## 11. IMAGE ENGINE

Build a genuine image-processing workspace.

Implement supported operations such as:

- Open and preview images.
- Crop and rotate.
- Flip and straighten.
- Resize using pixels.
- Resize by percentage.
- Resize using physical dimensions and DPI where meaningful.
- Preserve or change aspect ratio.
- Select resampling quality.
- Compress with adjustable quality.
- Convert between supported image formats.
- Change output dimensions.
- Convert color modes where supported.
- Remove or preserve metadata according to explicit settings.
- Compare original and output.
- Display source and output dimensions, format, file size and estimated output size.
- Batch-process multiple files.
- Undo or reset non-destructive edits.
- Save to a chosen destination.

Provide presets for common uses, including profile photos, ID-style photographs, document illustrations, email attachments, web uploads and print preparation.

Treat these as configurable examples, not guarantees that an image meets the requirements of every authority or website.

Allow users to specify exact pixel dimensions. Explain when aspect-ratio preservation prevents an exact fit.

For physical print dimensions, make the relationship between pixel dimensions and DPI clear.

Avoid silently enlarging low-resolution images and implying that genuine detail has been recovered.

Do not overwrite original files by default.

## 12. DOCUMENT CREATION AND EDITING

Provide practical document creation and editing rather than a decorative text screen.

Prioritize:

- Blank document creation.
- Editing plain text and supported rich text.
- Headings, paragraphs, lists and alignment.
- Page size, margins and orientation.
- Basic tables where supported.
- Page breaks.
- Images within supported documents.
- Save, Save As, Rename and export.
- Autosave drafts with reliable recovery.
- Recent documents.
- Explicit unsaved-change indicators.
- Undo and redo where the editor supports them.
- Share and print workflows.

Include professional templates such as:

- Formal letter.
- Application letter.
- CV or résumé.
- Invoice.
- Receipt.
- Meeting minutes.
- Report.
- Project proposal.
- Academic assignment.
- Business quotation.

Templates must generate editable documents with real formatting. Avoid storing every template as a static screenshot or a flat image.

Use fictional content and clearly mark example documents.

## 13. OFFICE FORMAT COMPATIBILITY AND LIBREOFFICE EVALUATION

Investigate genuine support for DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF, TXT, HTML and other relevant formats.

Do not promise universal conversion. Record which input/output combinations are supported, what fidelity can be expected, and what limitations apply.

Evaluate whether LibreOffice, a compatible headless office engine, an established document library, or a remote conversion service is appropriate.

Important constraints:

- LibreOffice is not a lightweight Android library that can automatically be embedded into any Flutter application.
- A desktop-oriented engine may require a separate service, additional platform integration or substantial packaging work.
- A remote service introduces network, privacy, operational and potential cost requirements.
- Third-party libraries may have commercial, copyleft or other licensing obligations.
- Spreadsheet formulas, macros, embedded objects, fonts, layout, complex tables and presentation animations may not survive conversion perfectly.

Document the technical alternatives and their trade-offs.

Select an implementation strategy that can actually be built, distributed, maintained and legally used.

Where full fidelity is not possible, preserve the original file, report the conversion limitations and offer an honest alternative.

Never rename a file extension and claim that its content has been converted.

## 14. FILE CONVERSION ENGINE

Create a centralized conversion registry.

Every conversion route must declare:

- Supported input format.
- Supported output format.
- Engine used.
- Required dependencies.
- Whether processing is local or remote.
- Expected fidelity.
- Resource requirements.
- Known limitations.
- Tests and verification method.

Implement high-value conversions first, including:

- Images to PDF.
- Supported PDF pages to images.
- OCR output to TXT.
- OCR output to supported editable document formats.
- Supported text and HTML to PDF.
- Supported image-format conversions.
- Supported office-format conversions where a real engine is available.

Validate file signatures and actual content, not only filename extensions.

Do not silently discard embedded media, fonts, formulas or document structure.

For every conversion, provide a preview when useful, a destination choice, progress, cancellation where safe, an output validation step and an actionable error message.

## 15. COMPRESSION AND SIZE OPTIMIZATION

Implement real compression rather than merely changing file extensions or metadata.

For images, support quality and dimension controls.

For PDFs, distinguish between:

- Image recompression.
- Image downsampling.
- Removal of unnecessary objects or metadata.
- Structural optimization.
- Other supported optimization methods.

Show estimated and final output sizes. Explain that compression may reduce quality and that some PDFs cannot be reduced significantly without altering content.

Where practical, provide presets such as:

- Maximum quality.
- Balanced.
- Smaller file.
- User-defined settings.

Preserve the original until the output has been verified.

Do not promise a specific percentage reduction before processing.

## 16. FILE WORKSPACE AND DOCUMENT MANAGEMENT

Build a coherent file-management experience that integrates with Android's storage system.

Support appropriate Android mechanisms such as the Storage Access Framework and Photo Picker where applicable.

Implement:

- Import files.
- Open supported files.
- Recent files.
- Search and filtering.
- Sort by name, date, type and size.
- Rename.
- Copy and move where permitted.
- Create folders where supported.
- Delete with confirmation.
- Multi-select.
- Share and export.
- File metadata.
- Storage-permission handling.
- Clear unsupported-format messaging.
- Duplicate-name handling.
- Safe temporary-file cleanup.
- Recovery from interrupted operations.

Avoid assuming that the application can freely access every directory on modern Android.

Use content URIs and persistable permissions appropriately. Do not hardcode access to unrestricted shared storage.

Protect user data from accidental deletion and avoid overwriting source files by default.

## 17. GOOGLE DRIVE AND OPTIONAL CLOUD INTEGRATIONS

Design cloud support as an optional capability rather than a prerequisite for basic use.

Investigate Google Drive integration through supported Google authorization and API mechanisms.

Potential capabilities include:

- Connect or disconnect an account.
- Browse authorized files.
- Import selected files.
- Upload processed outputs.
- Save drafts or exports to a chosen location.
- Resume or retry interrupted transfers.
- Show upload and download progress.
- Handle expired authorization.
- Avoid duplicate uploads where feasible.
- Respect the user's access and sharing choices.

Do not request a user's Google password inside DeskSuite.

Use supported authorization flows and minimum necessary permissions.

Never commit OAuth client secrets, refresh tokens, private keys or API credentials to GitHub.

Document the required Google Cloud project setup, OAuth configuration, scopes, consent requirements and any verification obligations.

Do not claim cloud integration works until the application has a real configured integration and the end-to-end flow has been tested.

### Storage and cost strategy

Use local storage for appropriate temporary work and user-selected local files.

Use Google Drive or another optional storage provider for user-controlled cloud storage where configured.

Do not assume Google Drive is a free, unlimited, automatic database replacement. Account quotas, API limits, policies, authorization and operational constraints still apply.

Keep cloud features modular so they can be configured when the product owner has the necessary credentials and project settings.

Basic scanning, image processing and file operations must remain usable without connecting a cloud account.

## 18. AI, SMALL LANGUAGE MODELS AND ADVANCED FEATURES

AI may be included where it solves a specific, measurable problem.

Potential uses include:

- OCR post-correction with review.
- Document-type classification.
- Table or form structure assistance.
- Suggested filenames.
- Summaries of user-selected text.
- Language detection.
- Optional translation.
- Guided document cleanup.

For each proposed AI feature, document:

1. The user problem.
2. Why a deterministic algorithm is insufficient.
3. Model or service choice.
4. Model size and hardware requirements.
5. Download or bundled storage requirements.
6. Offline versus online behavior.
7. Latency and memory usage.
8. Privacy implications.
9. Operating costs.
10. Accuracy evaluation and failure modes.
11. A non-AI fallback.

Prefer deterministic local algorithms for routine operations such as cropping, resizing, rotation, image encoding, file validation and basic PDF manipulation.

Use a small local model only when benchmarks demonstrate a meaningful improvement.

Do not ship a large model merely to meet an APK-size target.

If an optional model is downloaded separately, provide model size, storage requirements, download progress, integrity verification, deletion controls and a fallback for devices that cannot run it.

AI-generated tutorial samples must be reviewed, safely packaged and tested through the same engines used for user-generated tasks. The presence of generated sample content does not replace implementation of those engines.

Do not invent AI capabilities, fabricate OCR confidence or claim that a model has processed a file when it has not.

## 19. SECURITY, PRIVACY AND FILE INTEGRITY

Implement security throughout the application.

Requirements include:

- Request permissions only when needed.
- Explain camera and file-access permissions in context.
- Avoid uploading documents without explicit user action or clear consent.
- Protect temporary and sensitive files.
- Clean up temporary data safely.
- Validate imported file content and sizes.
- Handle malformed files without crashing the application.
- Avoid logging document contents, credentials or private paths unnecessarily.
- Keep secrets out of source control and build artifacts.
- Use secure network transport for cloud operations.
- Handle account disconnection and authorization revocation.
- Preserve original files during destructive processing.
- Provide clear behavior for deletion and local cache cleanup.

If password-protected or encrypted files are supported, use established cryptographic implementations rather than inventing custom cryptography.

Document realistic privacy guarantees. Do not claim that the application is completely private, secure or compliant without appropriate evidence.

## 20. PERFORMANCE AND PACKAGE SIZE

The product owner accepts a larger installable application, with a broad target of approximately 100–350 MB if technically justified.

Treat this as a planning range, not a minimum size or a requirement to fill the APK with unnecessary dependencies.

Optimize for actual value, reliability and maintainability.

Evaluate:

- APK and AAB sizes.
- Native library sizes.
- OCR model sizes.
- Startup time.
- Memory use.
- Camera responsiveness.
- Large-file handling.
- Battery consumption.
- UI frame performance.
- Background processing.
- Installation compatibility.
- Low-storage conditions.

Use Android App Bundles and architecture-specific delivery where appropriate. Evaluate Play delivery and direct-APK distribution separately.

Keep optional models and heavy components modular when this improves delivery without undermining core workflows.

Do not download large models or office engines at startup without user awareness.

For expensive tasks, display progress, allow safe cancellation, avoid UI freezes and handle process interruption.

Benchmark on real or representative Android hardware, including devices with constrained RAM and storage.

## 21. LANGUAGES AND ACCESSIBILITY

Prepare the product for international use.

Separate user-visible strings from business logic and avoid hardcoded text scattered across widgets.

Implement a coherent localization system. Select supported languages according to actual translation availability and testing.

Ensure layout, dates, numbers, units, filenames and text direction behave appropriately for supported locales.

Prioritize accessibility through readable text, scalable typography, semantic labels, adequate contrast, predictable navigation and non-color-only status indicators.

Do not present an incomplete translation as fully supported.

## 22. DATABASE AND LOCAL STATE

Keep the database appropriate to the actual data model.

Persist only what is necessary, such as:

- User preferences.
- Recent-file references and metadata where appropriate.
- Tutorial progress.
- User-created templates or project metadata.
- Local processing history where useful.
- Draft recovery information.
- Cloud connection metadata that is safe to store.

Do not copy all user documents into a growing application database without a compelling reason.

Large images, PDFs, extracted assets and generated documents should use suitable file storage rather than being indiscriminately stored as database blobs.

Design migrations and recovery paths. Do not delete existing user data during routine upgrades.

Use stable identifiers and ensure that a failed conversion does not corrupt the original file or leave misleading records.

## 23. ENGINEERING QUALITY AND TESTING

Every major capability must have appropriate tests.

Use the existing test framework where suitable and introduce new frameworks only when justified.

Required test categories:

- Unit tests for algorithms and processing services.
- Integration tests for conversion pipelines.
- Widget/UI tests for critical workflows.
- File-integrity tests.
- Regression tests for existing features.
- Error-handling tests.
- Large-file and resource-limit tests.
- Accessibility checks where practical.
- Build verification.
- Installation and launch tests.
- End-to-end tests using bundled sample assets.

For every supported conversion, verify that the output is structurally valid and can be reopened.

For PDF generation, inspect page count, dimensions, orientation and readable content where applicable.

For OCR, test known sample images and report recognition quality honestly.

For image resizing, assert the requested dimensions and verify that output files decode correctly.

For scanning, test perspective correction and manual crop behavior with known examples.

For file management, verify that rename, copy, move and deletion operate on the intended files.

For UI, test compact screen sizes and important system interactions.

A successful compilation alone does not establish that a feature works.

Do not disable or weaken tests just to produce a green build.

## 24. RELEASE ENGINEERING AND SIGNING

Inspect the current GitHub Actions configuration and make the release workflow reproducible.

Provide clearly distinguished outputs for:

- Debug builds.
- Testing builds.
- Release APKs.
- Android App Bundles where supported.

A release artifact must be signed correctly and verified before distribution.

Do not commit a private signing keystore or its password to the repository.

Use securely configured repository secrets or an appropriate protected signing setup. Document the required secret names and setup steps without exposing their values.

Ensure that repeated releases use the same intended signing identity so compatible upgrades can be installed over earlier releases.

Do not silently generate a new signing key for each release.

Preserve the existing Android application ID unless a deliberate, documented migration is approved.

Inspect version codes, version names, package metadata, permissions, minimum SDK and target SDK.

Keep CI logs useful but free of passwords, tokens and private credentials.

The workflow should build from a clean checkout and report meaningful failures.

Provide an installable APK for direct testing and an AAB where the distribution strategy requires it.

Do not claim that an artifact is ready until it has been built, signature-verified and subjected to available installation or launch tests.

## 25. DOCUMENTATION AND USER ORIENTATION

Create a practical user guide that explains real workflows.

Include:

- First launch and onboarding.
- Scanning a paper document.
- Creating a multipage PDF.
- Extracting text.
- Editing and exporting supported documents.
- Resizing images to exact pixel dimensions.
- Compressing supported files.
- Converting files between explicitly supported formats.
- Renaming and organizing files.
- Importing and exporting files.
- Connecting optional cloud storage.
- Troubleshooting common errors.
- Supported formats and known limitations.

Provide short, task-oriented instructions inside the application where useful.

Document each advanced feature's requirements, limitations and privacy behavior.

Create technical documentation for module boundaries, dependencies, build steps, signing configuration and test execution.

Ensure screenshots and examples match the actual implementation. Never illustrate a workflow with controls that do not exist in the released application.

## 26. IMPLEMENTATION PRIORITIES

Implement in controlled stages. Do not randomly add dozens of features simultaneously.

### Phase A — Audit and stabilization

- Inspect the complete repository.
- Identify functional code and placeholders.
- Record build and test baselines.
- Fix critical architectural and compatibility problems.
- Establish a clear module structure and implementation plan.

### Phase B — Product identity and UX foundation

- Create the logo and launcher icon.
- Establish the design system.
- Correct screen responsiveness.
- Improve navigation and application shell.
- Implement onboarding and sample-library foundations.

### Phase C — Core document workflows

- Camera capture.
- Document scanning and enhancement.
- Multipage PDF generation.
- OCR and text extraction.
- Image processing and resizing.
- Basic PDF reading and organization.
- File import, export and management.

### Phase D — Editing and conversions

- Document creation and editing.
- PDF page operations.
- Supported image conversions.
- Compression and size optimization.
- Office-format support based on the selected real engines.
- Templates and task-oriented workflows.

### Phase E — Advanced capabilities

- Optional cloud integrations.
- Additional OCR languages.
- Advanced PDF operations.
- Batch processing.
- Carefully justified AI-assisted capabilities.
- Further platform support where feasible.

### Phase F — Quality and release

- Regression testing.
- Real-device layout and workflow tests.
- Performance profiling.
- Security review.
- Dependency and licensing review.
- Signed release build.
- Verified installation.
- User and developer documentation.

Adjust this order if the audit reveals dependencies that require another sequence. Explain the reason for significant changes.

## 27. REQUIRED USER WORKFLOWS

The following workflows are product acceptance targets. Implement them with real engines and report any that remain incomplete.

### Workflow A — Paper document to searchable PDF

1. Open the scanner.
2. Capture a document.
3. Detect or manually define page boundaries.
4. Crop and correct perspective.
5. Enhance the scan.
6. Add, reorder or remove pages.
7. Run OCR.
8. Preview the generated PDF.
9. Save or share the searchable PDF.
10. Reopen the exported file and verify its content.

### Workflow B — Image to exact-size output

1. Import an image.
2. Inspect its original dimensions and format.
3. Enter target width and height in pixels.
4. Choose aspect-ratio behavior.
5. Select a supported output format and quality.
6. Preview the result.
7. Export to a new file.
8. Verify output dimensions and actual file size.

### Workflow C — Existing document to extracted text

1. Import a supported image or document.
2. Detect whether text is directly available or OCR is needed.
3. Run the appropriate extraction engine.
4. Display editable text.
5. Allow correction.
6. Copy or export the result.
7. Verify the exported text is readable and complete to the extent supported.

### Workflow D — Convert and compress

1. Select a supported source file.
2. Show the detected format and file size.
3. Present only valid output options.
4. Explain relevant quality or compatibility trade-offs.
5. Execute conversion or compression.
6. Validate the result.
7. Show the final file size.
8. Preserve the source and offer export or sharing.

### Workflow E — New-user sample tutorial

1. Open the tutorial library.
2. Select a bundled sample.
3. Review the original and instructions.
4. Execute the real processing pipeline.
5. Compare the output with the original.
6. Save or reset the sample result.
7. Revisit the tutorial without losing unrelated user files.

A workflow that fails at a critical step must show a useful error and allow recovery.

## 28. DEFINITION OF DONE

A phase is complete only when its acceptance criteria are satisfied.

The overall transformation must meet these standards:

- The application builds reproducibly from the repository.
- The core navigation and layout are polished and responsive.
- The app has its own production-quality launcher icon and visual identity.
- New users can understand and complete real workflows.
- Core camera, scan, OCR, PDF and image operations use actual engines.
- Supported conversions generate valid outputs.
- Sample tutorials use real processing services.
- User files are handled safely and predictably.
- Long-running operations do not freeze the UI.
- Existing working functionality remains intact.
- The release workflow signs artifacts consistently.
- Automated tests cover critical processing paths.
- Documentation matches the implemented product.
- Unsupported capabilities are clearly identified instead of being advertised as working.
- Remaining work is explicitly documented.

## 29. REPOSITORY EXECUTION AND AGENT RULES

Make actual changes in the existing online repository.

1. Start by inspecting the current branch, working tree, recent commits, project files and CI workflow.
2. Preserve user changes and inspect uncommitted work before any cleanup.
3. Do not overwrite useful code simply to impose a preferred architecture.
4. Avoid unrelated refactors and unnecessary dependency additions.
5. Introduce dependencies only after reviewing compatibility, maintenance, licensing, size and security.
6. Keep changes grouped into logical, reviewable commits.
7. Run appropriate tests after each substantial implementation stage.
8. Fix regressions caused by your changes before proceeding.
9. Update documentation as behavior changes.
10. Keep the default branch buildable where practical.
11. Do not report a task as complete unless the repository evidence supports that statement.
12. Do not invent test results, build results, repository changes or successful device tests.
13. Do not expose secrets in source code, logs, commits or generated artifacts.
14. Do not delete branches, rewrite history, replace the application ID or perform destructive release operations without a clear technical reason and appropriate approval.
15. If a critical external credential is unavailable, complete the non-blocked implementation, provide a mock only for automated tests, and document the exact configuration required for live integration.
16. If a tool, dependency or agent cannot deliver a requested feature, investigate a viable alternative before marking the feature blocked.

After each major phase, report:

- What changed.
- Important files and modules affected.
- Which real workflows now work.
- Tests executed and their actual results.
- Build artifact status.
- Remaining defects and limitations.
- Any required manual setup.
- The next bounded implementation stage.

Do not overwhelm the product owner with repetitive status messages or enormous raw logs. Provide concise summaries backed by specific evidence.

## 30. FINAL PRODUCT STANDARD

DeskSuite should feel like one professionally engineered product, not several unrelated tools bundled together.

The UI, internal architecture, file handling, processing engines, tutorials, branding, release workflow and documentation must reinforce one another.

Prioritize the quality of real task completion over promotional language, decorative AI labels, artificial feature counts or inflated claims.

Use professional judgment to resolve routine implementation details, delegate specialized work responsibly and keep all components integrated.

Begin with the repository audit and proceed into implementation without waiting for another general approval. Do not stop after producing the audit, a plan, a redesigned home screen or an initial prototype.

Implement the highest-value complete workflows first, verify them, and continue iteratively until the defined acceptance criteria are met.

The objective is a genuinely useful, premium, extensible DeskSuite product that can be tested, installed, maintained and improved—not merely an attractive early-stage application.


## 31. CREATIVE STUDIO, ID/PASSPORT PHOTOGRAPHY, TEMPLATE LIBRARY AND OPTIONAL SLM TOOLS

This is a first-class product area, not a future footnote and not a PDF subfeature. DeskSuite must serve both **print-ready output** and **digital/soft-copy use**. Implement these capabilities through the existing shared image, project, asset, export, print and design services; do not build parallel one-off engines inside screens.

### 31.1 ID and passport photo workflow — assisted and manual

Provide a dedicated Photo & ID Studio that can begin with a camera capture or imported image and supports both a guided automatic route and a complete manual route:

1. Import/capture, apply orientation correction, inspect resolution and preserve the untouched original.
2. Offer a user-selectable target preset (country/authority and document type where requirements are known), with width/height in mm, output pixels, DPI, head-size/eye-line guidance, background requirements and source/version notes. Never imply a universal passport standard; requirements vary by authority and can change.
3. Detect a person/face and estimate pose/landmarks only with an evaluated, licensed, on-device-capable engine. Suggest a crop that places the head and shoulders/chest at an appropriate level for the selected preset. Show a visible crop frame and let users adjust it manually; never silently decide compliance.
4. Remove or refine the background with edge-aware foreground segmentation, hair/soft-edge refinement and an editable mask. Keep the original and mask recoverable; provide brush/erase/refine controls and a no-model/manual fallback.
5. Place the subject on selectable backgrounds: neutral white, off-white, light grey, pale blue and other user-defined solid colours, plus approved gradients/textures and optional studio styles. Include a plain-background preset first for identity photographs. Preview at actual size and check for halos, cut-out edges, shadows and colour spill.
6. Apply optional conservative lighting/colour balancing; do not reshape identity, alter facial features, fabricate details or conceal that the background was changed. Flag possible shadows, clipped hair, low resolution and poor contrast instead of guaranteeing acceptance.
7. Export one image, a digital upload version and a print sheet. Print sheets must support configurable photo dimensions, page size, margins, gutters, count, crop marks where appropriate, and verified pixel/DPI calculations. Preserve aspect ratio unless the user explicitly chooses a crop or stretch.
8. Save an editable project with source reference, crop, mask, background, preset, export settings and processing history. Make the final soft-copy easy to share/save separately from the print sheet.

Provide clear manual controls at every consequential automatic step. Face/pose analysis and segmentation should be local by default where feasible; do not upload personal photographs to a service without explicit, informed consent. Warn users that image editing cannot guarantee compliance with official identity-document rules.

### 31.2 Background removal and image enhancement

Evaluate the best practical segmentation options rather than pretending a simple colour threshold is a universal background remover. Compare classical algorithms for suitable plain backgrounds against compact segmentation models for general scenes. Assess model licence, model provenance, offline operation, download size, RAM/CPU, cold-start latency, output quality on hair/transparent objects and performance on a modest Android phone.

The shared image pipeline should eventually support: foreground mask generation; edge refinement/decontamination; feathering; hole repair; transparent PNG export; replacement background composition; undo/reset; before/after comparison; batch operation with limits; cancellation; and graceful low-memory failure. Do not add multiple competing segmentation engines without measured reasons. Model files must be versioned, checksummed, licensed, and downloaded only with user consent when they are not bundled.

### 31.3 Professional template catalogue — editable and extensible

Create one searchable, categorized template catalogue backed by editable project data and licensed assets, not a gallery of flattened screenshots. Initial categories must include:

- Passport/ID photos: authority-specific configurable presets, neutral backgrounds and print sheets.
- School IDs: student portrait, name, admission/registration number, school, class, academic year, emergency/authorized fields, logo and QR/barcode placeholders. Clearly mark sample data as fictional and make sensitive fields optional.
- Staff/work IDs, visitor badges, event badges, conference badges and access cards.
- Business cards, contact cards and simple brand stationery.
- Posters, flyers, invitations, announcements, certificates, menus, price lists and promotional social images.
- Office documents: letters, CVs, invoices, quotations, receipts, reports and meeting minutes.
- Presentations: multiple coherent PowerPoint-style themes and slide layouts (title, section, text/image, two-column, data/chart, timeline, comparison, closing), with consistent master colours, typography and spacing.
- Print-production layouts: A4/A5/Letter, configurable cards, labels, sticker sheets, multi-up imposition, margins, bleed and crop marks where supported.

Each template needs a unique stable ID, category, display name, dimensions/unit, intended use, editable element tree, theme tokens, thumbnail/preview, required optional fields, supported export routes, source/licence attribution and version. Build reusable typography, layout, colour, shape, image-frame and QR/barcode components. Keep content editable; do not treat a preview thumbnail as the document itself. Include duplicate/customize, search/filter, favourites/recent, replace-image, data-field mapping, and safe template version migration.

Ship a curated starter library first and make the catalogue expandable through properly licensed, optional packs. Do not claim “thousands of templates” until those assets exist, are indexed and tested. Prefer quality, variety and a clean design language over a large collection of near-duplicates.

### 31.4 Small language models (SLMs) and companion engine integrations

Introduce a capability-based optional local-model layer only where it measurably improves a real workflow. Potential tasks include OCR post-correction suggestions, document/form classification, layout-aware field suggestions, template recommendations, background/subject workflow guidance and presentation-outline assistance. A model must never replace OCR, deterministic measurement, file validation, colour/geometry operations, transactional accounting or the actual export engine.

Before choosing a runtime, benchmark viable candidates (for example, llama.cpp/GGUF, ONNX Runtime, LiteRT/TFLite or MediaPipe-supported paths where suitable) against the target Android ABI, Flutter/native bridge maintenance, model and runtime licences, quantization, memory pressure, thermal behavior, latency, offline use, language coverage and packaging size. These are candidates for evaluation, not a mandate to bundle all of them. Prefer one supported runtime per actual model family, behind a stable service interface, and avoid unnecessary native binaries.

Requirements:
- Feature flags and capability discovery so core app workflows work without any SLM installed.
- On-device-first execution and explicit consent for any remote inference.
- Optional model download with size, source, checksum, licence and storage disclosure.
- Quantized small-model profiles appropriate for low-memory phones; lazy loading, cancellation, timeout, resource limits and unload/release.
- Structured request/result contracts, model versioning, deterministic fallback and visible failure states.
- User review before any model-generated OCR correction, rewritten text, document classification or suggested crop is applied.
- Never send identity photos, document text or business records to remote services by default.
- No fabricated claims of model accuracy, no silent replacement of source text and no requirement to pay for an API to use core features.
- A benchmark fixture set covering Kiswahili and English where available, printed text, low light, mixed layouts, privacy and false-positive behavior.

Treat OCR, image segmentation, face/pose landmarks, PDF rendering, Office conversion, QR/barcodes, vector/SVG rendering and print/imposition as distinct companion-engine integrations. Evaluate each by supported input/output, Android and desktop viability, offline behavior, licence, maintenance, memory, security, test fixtures and failure recovery. Reuse the existing Tesseract OCR integration and language packs where they meet requirements; do not introduce a second OCR engine without a documented accuracy or platform justification. Evaluate whether any added native engine is really usable in a Flutter Android build and how it will be packaged for desktop before integrating it.

### 31.5 Shared architecture and definition of done

All these capabilities must use the shared project/asset catalogue, file gateway, theme/design tokens, background-task/result conventions, export registry, print gateway, recent-files/search and recovery mechanisms. Template, model and engine registries must not become isolated screens or orphan modules.

A feature is not complete until:
- it accepts real files or data and produces a valid, reopenable output;
- originals remain recoverable and edits can be reset or revised;
- output dimensions, crop, transparency, background and print layout are verified by tests;
- templates remain editable after save/reopen and work at target export sizes;
- model-offline, model-missing, cancellation, corrupt-input and low-memory cases are tested;
- assets/models have recorded provenance, licences and checksums where relevant;
- performance is measured on a modest Android device, not inferred from desktop tests;
- limitations are stated honestly, with no claim that an edited ID/passport photo is officially compliant.

These requirements extend the existing product scope; they do not displace document scanning, OCR/Tesseract, Office, PDF, image, print-production, stationery POS, file management, backups, accessibility or release-quality work.


## Print-production engineering gate — mandatory

Follow [`PRINT_PRODUCTION_STANDARDS.md`](PRINT_PRODUCTION_STANDARDS.md) for all photo, passport/visa portrait, card, badge, stationery, poster, paper, card-stock, photo-stock and large-format workflows. Never conflate finished-item size, source sheet/roll size, substrate properties, printer-supported media and issuing-authority requirements. A4/A3 are paper formats, not passport-photo specifications. Use sourced authority-scoped photo profiles; preserve unknown dimensions as unspecified; separate digital-upload constraints from paper-submission rules. Print geometry must use physical units, account for printable margins/bleed/trim, reject impossible layouts, preserve requested scale, and test actual PDF page dimensions. Do not claim device/media compliance without printer-specific validation.
