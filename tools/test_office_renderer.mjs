// Host smoke for the *same* capped OpenDocument.core WASM and worker used by
// the Android preview. Supply a directory with the named Office/ODF upstream
// fixtures and encrypted.docx; no network is used here. See OFFICE_SUPPORT.md.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assets = path.join(root, 'android/app/src/main/assets/office_engine');
const wasmBytes = fs.readFileSync(path.join(assets, 'odr-core.wasm'));
assert.equal(crypto.createHash('sha256').update(wasmBytes).digest('hex'), '4801d59d42ddf95e7d7ccfae104f5943e2242e9630c458bddd416c31ad48aaca');
const wasm = new WebAssembly.Module(wasmBytes);
const imports = {};
for (const entry of WebAssembly.Module.imports(wasm)) {
  assert.equal(entry.kind, 'function');
  (imports[entry.module] ||= {})[entry.name] = () => 0;
}
const instance = new WebAssembly.Instance(wasm, imports);
const memoryName = WebAssembly.Module.exports(wasm).find((item) => item.kind === 'memory').name;
const memory = instance.exports[memoryName];
assert.equal(memory.buffer.byteLength, 32 * 1024 * 1024);
assert.throws(() => memory.grow(4096), RangeError, 'WASM memory maximum must block growth past 256 MiB');

let messages = [];
globalThis.self = { postMessage: (message) => messages.push(message) };
await import(pathToFileURL(path.join(assets, 'worker.js')));
const send = async (message) => {
  messages = [];
  await self.onmessage({ data: message });
  assert.equal(messages.length, 1);
  return messages[0];
};

let result = await send({ kind: 'open', name: 'empty.doc', bytes: new Uint8Array(0) });
assert.equal(result.kind, 'error');
result = await send({ kind: 'open', name: 'large.doc', bytes: new Uint8Array(8 * 1024 * 1024 + 1) });
assert.equal(result.kind, 'error');
result = await send({ kind: 'open', name: 'bad.doc', bytes: new Uint8Array([1, 2, 3]) });
assert.equal(result.kind, 'error');

const localDir = path.join(root, 'test/fixtures/office_preview');
for (const [name, expectedViews] of [['preview.docx', 1], ['preview.xlsx', 2], ['preview.pptx', 2], ['preview.xls', 2]]) {
  result = await send({ kind: 'open', name, bytes: new Uint8Array(fs.readFileSync(path.join(localDir, name))) });
  assert.equal(result.kind, 'opened', name);
  assert.equal(result.views.length, expectedViews, name);
  result = await send({ kind: 'render', position: 0 });
  assert.equal(result.kind, 'rendered', name);
  assert.ok(result.html.includes('DeskSuite Preview'), `${name} is missing expected fictional text`);
  if (expectedViews > 1) {
    result = await send({ kind: 'render', position: 1 });
    assert.equal(result.kind, 'rendered', `${name} second view`);
    assert.ok(result.html.includes(name.endsWith('.pptx') ? 'Second slide' : 'Local sample'));
  }
  console.log(`${name}: ${expectedViews} fictional view(s) rendered`);
}
const dir = process.argv[2];
if (!dir) {
  console.log('Local fixture, WASM memory and invalid-input tests passed. An optional fixture directory adds legacy DOC/PPT, ODF and encryption coverage.');
  process.exit(0);
}
const cases = [
  ['11KB.doc', 'Buy Used Book', 1],
  ['11KB.docx', 'Buy Used Book', 1],
  ['file_example_XLS_10.xls', 'First Name', 1],
  ['file_example_XLSX_10.xlsx', 'First Name', 1],
  ['style-various-1.ppt', 'title1', 8],
  ['style-various-1.pptx', 'title1', 8],
  ['mixed-layout.odt', 'Portrait ', 1],
  ['file_example_ODS_10.ods', 'First Name', 1],
  ['style-various-1.odp', 'title1', 6],
];
for (const [name, marker, expectedViews] of cases) {
  const bytes = new Uint8Array(fs.readFileSync(path.join(dir, name)));
  result = await send({ kind: 'open', name, bytes });
  assert.equal(result.kind, 'opened', name);
  assert.equal(result.views.length, expectedViews, name);
  result = await send({ kind: 'render', position: 0 });
  assert.equal(result.kind, 'rendered', name);
  assert.ok(result.html.includes(marker), `${name} must contain its expected fixture text`);
  assert.ok(result.html.includes('<html'), `${name} must produce an HTML view`);
  console.log(`${name}: ${expectedViews} view(s); expected text present; HTML ${result.html.length} characters`);
}
result = await send({ kind: 'open', name: 'encrypted.docx', bytes: new Uint8Array(fs.readFileSync(path.join(dir, 'encrypted.docx'))) });
assert.equal(result.kind, 'error');
assert.match(result.text, /Password-protected/);
result = await send({ kind: 'render', position: 0 });
assert.equal(result.kind, 'error', 'closed/encrypted document must not render a previous file');
console.log('Six Office and three OpenDocument formats plus encrypted/invalid inputs passed under Node. Visual fidelity and Android isolation are not tested here.');
