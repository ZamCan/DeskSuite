# Corresponding source: experimental OpenDocument.core preview

- Upstream C++/WASM source: `OpenDocument.core-7.6.1.tar.gz`, from
  `https://codeload.github.com/opendocument-app/OpenDocument.core/tar.gz/4a1ce6e505a325147f6d3360d29625aa432a669a`,
  SHA-256 `d0727fdc68545dd637a9f32632e3f7ef98a2cd46a9d84a006d887c2d678a7a3f`.
  Release v7.6.1 identifies commit `4a1ce6e505a325147f6d3360d29625aa432a669a`.
  It includes its MPL-2.0 licence and the source of the bindings and renderer.
- Corresponding uchardet 0.0.8 source: `uchardet-0.0.8.tar.xz`, from
  `https://www.freedesktop.org/software/uchardet/releases/uchardet-0.0.8.tar.xz`,
  SHA-256 `e97a60cfc00a1c147a674b097bb1422abd9fa78a2d9ce3f3fdcc2e78a34ac5f0`.
  Upstream Conan identifies it as MPL-1.1; its `COPYING` is included separately
  in `../opendocument-core/uchardet.txt`.
- DeskSuite ships npm `@opendocument/odr-core` 7.6.1 `index.js` and
  `odr-core.mjs` unchanged. Its `odr-core.wasm` differs from upstream only in
  the memory section's maximum: 65,536 to 4,096 WebAssembly pages (4 GiB to
  256 MiB). `../../tools/patch_odr_wasm_memory.py` verifies the upstream hash,
  documents and reproducibly applies this binary modification. The
  source-level equivalent is the `-sMAXIMUM_MEMORY=268435456` link option in
  `wasm/CMakeLists.txt`; the script does not claim to rebuild the artifact.
- DeskSuite's adapter/worker/UI code is in `android/app/src/main/assets/office_engine/`
  and `android/app/src/main/java/com/zamcan/desksuite/`. The upstream licence
  and collected dependency notices are in `../opendocument-core/`, assembled
  for the in-app licence page by `../../tools/generate_office_notices.py`.

The upstream Conan recipe lists pugixml, Crypto++, fmt, md4c, miniz,
nlohmann_json, OpenJPEG, uchardet and utfcpp; its lock also names further
transitive/build dependencies. The exact statically linked closure and every
app-distribution licence/notice/source obligation still require a release
binary audit. See `../../THIRD_PARTY_NOTICES.md` and
`../../docs/engineering/OFFICE_SUPPORT.md`.
