# Architecture

## Decision

The audited repository contained only an Apache-2.0 licence and an initial commit; there was no stack or implementation to preserve. Flutter 3.47.8 was selected for an Android-first application with a shared Dart model and a later path to Windows/Linux. Only the Android runner is included today. Flutter's desktop capability is a future option, not a claim of desktop support or testing.

## Dependency direction

- `lib/design/design_document.dart`, `geometry.dart`, `design_controller.dart`: versioned immutable document/object values, millimetre geometry, hit testing, editing operations and session history. They do not access storage or a network.
- `lib/design/design_renderer.dart`: Flutter canvas renderer and bounded local image decode cache. The same renderer supplies editor preview and raster export; selection decoration is excluded from exports.
- `lib/printing/design_export.dart`: millimetres/dpi to pixels and PDF points, bounded PNG rasterisation, image-resolution warnings and one-page PDF output. PDF encoding runs in a Dart isolate.
- `lib/workspace/project_repository.dart`: app-private, queued local file storage, validated IDs and versioned JSON. Same-directory temp files are flushed and renamed; Windows uses a backup-and-replace fallback. Recovered `.bak` files are surfaced on listing. Filesystem durability after abrupt power loss and Windows behaviour have not been verified on hardware.
- `lib/workspace/file_gateway.dart`: platform file-picker boundary for imports and user-selected exports. UI uses this interface, allowing test doubles without platform plugins.
- `lib/app`, `lib/main.dart`, workspace and editor screens: theme, navigation, accessibility labels, project actions, autosave and UI. The Android runner is under `android/`.

Rendering converts document millimetres into a viewport scale. Text uses point-to-mm conversion and the Flutter system font; no font is embedded into the PDF because output is raster. Images are embedded in project JSON rather than referenced through external paths. A document is not a flattened screenshot, although its current exported PDF is rasterised.

## Persistence and lifecycle

The editor debounces saves by 700 ms and flushes before leaving. Failures keep edits in memory, show a retry action, and require an explicit discard confirmation before leaving; exporting a project copy remains available. Sudden termination before the pending save completes can lose recent changes. The version-1 JSON file includes project dimensions, ordered layers, transforms, styles, text and base64 image bytes. Imports receive a fresh ID to avoid overwriting existing work. Undo/redo history is in memory, capped at 40 snapshots, and is not restored after closing the editor.

## Platform seams and future work

The picker and repository are separate from editing logic. Physical printers, operating-system shares, image processing, a local database, documents and spreadsheets do not yet have production adapters. Add those only as complete, tested responsibilities; do not claim cross-platform support until runners and platform tests exist.
