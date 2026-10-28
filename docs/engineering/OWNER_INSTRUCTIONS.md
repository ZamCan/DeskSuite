# Product-owner instructions and preservation

The authoritative product brief is [MASTER_ENGINEERING_DIRECTIVE.md](MASTER_ENGINEERING_DIRECTIVE.md). It contains the full directive supplied by ZamCan (Mussa Fikiri Ngwegelo), formatted as Markdown. It is a statement of requirements, **not** evidence that those requirements are complete. The current implementation and remaining work are recorded in [CURRENT_STATUS.md](CURRENT_STATUS.md), [BASELINE_AUDIT.md](BASELINE_AUDIT.md) and [VALIDATION.md](VALIDATION.md).

The owner also gave these operational instructions during the project conversation:

- Preserve existing work, data, useful functionality, the application ID and `main` history. Inspect all branch tips before modifying or cleaning up; do not rewrite `main` history or force-push. The owner's later directive on 2026-10-28 supersedes the earlier request to retain every branch: after the full audit, retire redundant/superseded remote refs and leave `main` as the sole branch.
- Prioritize genuine, tested, local-first Android workflows over mock controls or superficial feature coverage. Essential workflows must not require an account, paid API, analytics or silent model downloads.
- Do not install or download Android toolchains or perform online APK packaging here. The owner has existing Termux/Debian-side tools and intends to clone/pull and build packages locally. Use already available tools where appropriate; report build, signing and device-test blockers honestly.
- Keep credentials and signing keys out of code, commits, logs and artifacts. A token mentioned in a separate chat is not assumed to be available here; do not invent or repeat one.
- Proceed without requesting another general approval for routine engineering, but ask before an important irreversible or genuinely ambiguous decision.
- Do not describe OCR, searchable PDF, Office conversion, a signed release, device tests or any other capability as complete unless the repository and actual validation support the claim.

## Preservation and integration

Keep the source changes, the full directive, status and validation records together in version control. If a push cannot be authenticated, preserve them in a verified Git bundle based on the current upstream, and state clearly that the work is not on GitHub yet. A separately developed remote branch can advance independently; inspect and reconcile it before merging, without replacing or deleting it. A successful push does not substitute for testing, native signing, installation or release approval.
