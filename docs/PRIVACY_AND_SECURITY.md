# Privacy and security

- No account, cloud service, telemetry or analytics is implemented. The core test workflow runs with Dart HTTP blocked, but Android airplane-mode testing remains outstanding.
- The Android main manifest does not request network or broad storage permissions. The generated **debug** manifest requests `INTERNET` for Flutter debugging; plugin-merged manifests must also be inspected during release review. A system file picker provides user-selected access.
- Project and setting files are kept in app-private storage. DeskSuite does not encrypt them. Other software with privileged device access, device backups or a compromised device may expose them.
- Android uninstall/clear-data can remove app-private projects. Users should export `.dsdesign` copies and protect them separately. There is no bulk backup/restore yet.
- Project IDs and structure are validated; file sizes, image dimensions and output raster size are limited. No dynamic code or external project paths are deserialized. Image decoding still relies on platform/Flutter codecs and must be reviewed and updated with dependencies.
- Saves use a same-directory temporary file followed by rename; old data is preserved on tested write failures. Very recent edits may be lost if the app is killed before the 700 ms autosave, or during untested power-loss conditions.
- Dependency versions are pinned in `pubspec.lock`. No signing key or personal token should be committed. GitHub credentials pasted into a chat should be revoked after use.
