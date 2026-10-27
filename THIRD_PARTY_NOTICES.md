# Third-party notices

DeskSuite's repository code is licensed under [Apache-2.0](LICENSE). Direct dependencies resolved by `pubspec.lock` in this integration snapshot include:

| Component | Resolved version | Licence / notice |
| --- | --- | --- |
| Flutter SDK and Dart framework | Flutter 3.47.8 used for host checks | [BSD-style Flutter licence](third_party/flutter.LICENSE) |
| file_picker | 13.1.0 | [MIT](third_party/file_picker.LICENSE) |
| path_provider | 2.1.6 | [BSD 3-Clause](third_party/path_provider.LICENSE) |
| image | 4.12.0 | [MIT](third_party/image.LICENSE); [additional codec notices](third_party/image-additional-notices.md) |
| pdf | 3.13.1 | [Apache-2.0](third_party/pdf.LICENSE) |
| printing | 5.15.1 | [Apache-2.0](third_party/printing.LICENSE) |

`flutter_lints` 6.0.0 is a development dependency. Platform implementations and transitive packages are listed in `pubspec.lock`; the notices above are **not a complete binary licence audit**. Flutter's generated licence registry includes package notices; review all transitive, Android and desktop native licences before distribution. The Gradle wrapper scripts carry their own Apache-2.0 headers. The checked-in Gradle distribution URL and SHA-256 are in `android/gradle/wrapper/gradle-wrapper.properties`.

The launcher mark was made for DeskSuite. No paid assets, remote fonts, online model weights or external image assets are bundled in the app.
