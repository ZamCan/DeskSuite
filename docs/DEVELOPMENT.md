# Development guide

Requirements: Flutter stable, Git, Android SDK and compatible JDK for Android; Windows with Visual Studio C++ tools for Windows; Linux desktop dependencies for Linux; macOS and Xcode for iOS.

First setup:

    git clone https://github.com/ZamCan/DeskSuite.git
    cd DeskSuite
    flutter create --project-name desksuite --org com.zamcan.desksuite --platforms=android,ios,windows,linux .
    flutter pub get

Quality checks:

    dart format --set-exit-if-changed lib test
    flutter analyze
    flutter test

Android:

    flutter build apk --release
    flutter build appbundle --release

Desktop:

    flutter build windows --release
    flutter build linux --release

iOS validation:

    flutter build ios --release --no-codesign

Unsigned iOS output is not an App Store-ready IPA. Final distribution needs Apple signing and provisioning. For Termux, check flutter doctor -v and diagnose the first meaningful error before changing source or deleting caches.

After dependencies are fetched, test core workflows offline: create/edit/save/reopen a design, transform a photo, save notes, and export a PDF.
