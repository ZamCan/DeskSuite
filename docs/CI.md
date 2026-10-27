# Continuous integration

This branch includes a **proposed, inactive** workflow at [`ci/flutter.yml.example`](../ci/flutter.yml.example). It pins action revisions, installs JDK 21 and Flutter 3.47.8, resolves the lockfile, checks formatting and analysis, runs host tests, and builds a debug APK. It does not sign a release or upload an artifact. It has not been run on GitHub Actions.

The authenticated push rejected a file under `.github/workflows/` because the supplied fine-grained token did not have workflow-write permission. The application branch was pushed without changing active workflows. The proposed workflow also remains in local commit `32881f0` on `agent/creative-studio-ci`.

After the two concurrent app implementations and the existing `main` workflow have been reconciled, a maintainer can review the example, grant an appropriately scoped GitHub token **Contents: read and write** and **Workflows: read and write**, place the reviewed file at `.github/workflows/flutter.yml`, and push it. Verify the resulting run, dependencies, Android artifact and platform matrix rather than assuming success. Protect release signing secrets outside the repository. Do not replace `main`'s existing workflow without review.
