# Android build and phone installation

DeskSuite's Android application ID is `com.zamcan.desksuite`. To update an existing installation, Android requires the new APK to be signed by the same signing certificate. Remembering a password is not enough if the original keystore file or alias is missing. **Never uninstall the existing app merely to bypass a signature mismatch.**

## 1. Find and protect the existing key

From Termux, inspect likely key locations without printing passwords:

```bash
find "$HOME" -type f \( -name '*.jks' -o -name '*.keystore' \) -print 2>/dev/null
```

If you already have the correct keystore, copy it to a private, backed-up location. Do not upload it to GitHub or send it in chat. Check its aliases locally with Android's `keytool -list -keystore /absolute/path/to/your-existing-key.jks`; enter the password only at the interactive prompt.

## 2. Configure local release signing

`android/key.properties` is ignored by Git. Create it from the example and use the path and alias for the **existing** key:

```bash
cd ~/DeskSuite
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties` locally. Set `storeFile` to an absolute path, and fill `keyAlias`, `storePassword` and `keyPassword`. Keep the file and keystore private. If the existing app was signed with a different key and you cannot recover it, stop before attempting an update.

## 3. Build and verify first, without installing

```bash
cd ~/DeskSuite
bash tools/android-build-phone.sh
```

This runs dependency resolution, static analysis, builds the release APK and verifies its signing certificate. It does not install or remove anything.

## 4. Safely install/update on this phone

For the safest update, connect ADB to this same phone using **Developer options → Wireless debugging**. Pair/connect using the pairing IP/port shown by Android, then verify:

```bash
adb devices
```

The device must show as `device`, not `unauthorized`. Then run:

```bash
bash tools/android-build-phone.sh --install
```

Before updating an existing DeskSuite installation, the script pulls the installed base APK, compares its signing-certificate SHA-256 with the new APK, and refuses to install if the signatures differ. If no DeskSuite package is installed, it installs the signed APK. Android can still refuse an update if the new version code is lower; do not use a downgrade workaround on an important installation.

If you cannot use ADB, the built APK is at `build/app/outputs/flutter-apk/app-release.apk`. You can open it with `termux-open build/app/outputs/flutter-apk/app-release.apk` and follow Android's installer. However, that manual route cannot pre-check the installed signature; do not proceed if Android reports a signature conflict.

## What this proves

A successful build and signature check proves the APK was built and signed by the configured key. It does not prove that every camera, printer, document, OCR, or Office workflow works on physical hardware. Test the app after installation and keep a separate backup of important documents.
