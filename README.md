# DeskSuite

**Create. Design. Print. Manage.**

DeskSuite is an offline-first creative and productivity workspace for editable graphic layouts, local photo processing, notes, print-ready PDF output, and stationery-shop product tracking.

## Current implementation status

This is a real application foundation, not a claim of full Canva or Microsoft Office feature parity.

- Creative canvas: editable text, rectangles, circles, imported images, drag positioning, duplicate/delete, undo/redo.
- Local projects: versioned JSON project files saved on-device.
- PDF: export current design objects and open a supported system print dialog.
- Photo tools: local import, rotate, flip, resize and JPEG export.
- Office notes: local autosave and TXT export.
- Print Studio: A4 PDF test sheet and print dialog.
- Business starter: local product catalogue and simple stock decrement.
- Not yet implemented: advanced design tools, automatic background removal, full DOCX/XLSX compatibility, complete POS/accounting/receipts, production-grade print management.

## Platforms

Flutter provides a shared codebase for Android, iOS, Windows and Linux. Platform scaffolding is generated using Flutter tooling. iOS distribution requires Apple's signing and provisioning. A signed App Store release cannot be produced from Termux.

## Setup

Install a compatible Flutter stable SDK and platform toolchains.

    git clone https://github.com/ZamCan/DeskSuite.git
    cd DeskSuite
    flutter create --project-name desksuite --org com.zamcan.desksuite --platforms=android,ios,windows,linux .
    flutter pub get
    flutter analyze
    flutter test

## Android APK

    flutter build apk --release

The APK is normally at build/app/outputs/flutter-apk/app-release.apk.

## Desktop and iOS builds

    flutter build windows --release
    flutter build linux --release
    flutter build ios --release --no-codesign

Windows requires Windows and Visual Studio C++ tools. Linux requires desktop development libraries. iOS requires macOS and Xcode. The no-codesign iOS build is for validation, not an App Store-ready signed IPA. The Windows EXE must be distributed with its runtime files.

## Termux

Android builds under Termux depend on the installed Flutter, Java, Android SDK and filesystem setup. Check flutter doctor -v and the first meaningful build error before changing application code. If the local toolchain cannot build, use GitHub Actions artifacts after the workflow passes.

## Offline data

Projects, notes and the initial product catalogue are stored in the app's local support directory. Core editing and image transformations do not call remote APIs. Export dialogs and printer availability depend on the operating system.

See docs for architecture, roadmap, development, file formats/printing, and privacy/security.

## License

Apache License 2.0. See LICENSE.
