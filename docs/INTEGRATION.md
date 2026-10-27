# Integration with concurrent `main` work

On 2026-10-27, after development began from `86aa321`, the remote `main` advanced to `ee04d7d` with a separate Flutter foundation and subsequently to `d0bd941` with picker/CI changes. It contains creative editing, Photo Studio, Notes, system printing, a starter product catalogue and stock decrement, an Android build script, and a desktop/iOS/Android workflow. Those commits remain on `main`; this branch intentionally does **not** overwrite them. This branch is based on the earlier commit and is not a merge of that work.

The current branch is a more fully tested creative-to-export slice, not a drop-in replacement for every prototype feature. Do not merge by choosing this branch's files wholesale: doing so would remove the other branch's available tools, build script and workflow. A safe integration should:

1. Fetch current `main` again and review all changes since `ee04d7d` before beginning a merge; do not force push.
2. Bring the photo, notes, printing and business tools into the new navigation without losing their data. Harden input/size checks, errors, file writes and stock transactions, and add behavioural and device tests before claiming release readiness.
3. Resolve the different Android app IDs and private-data directories explicitly. Do not assume app-private data can be read across application IDs; back up and verify any migration before altering an existing installation.
4. Preserve and adapt `tools/build-android.sh` and the existing build matrix deliberately, including signing and platform verification. Never advertise an unsigned/debug build as a production release.
5. Test both branches' workflows and perform a real Android offline/picker/print and upgrade test before merging to `main`.

The new editor can **import a copy** of the earlier schema-1 `.dsproject` file when the user can access it. It maps the old logical units to millimetres using the earlier PDF's 96-units-per-inch conversion and creates a new project ID. Some rendering may differ; new size limits apply; unknown layers are rejected. The source file is never changed. Import does not automatically find private files from a different app installation. See [FILE_FORMATS.md](FILE_FORMATS.md).
