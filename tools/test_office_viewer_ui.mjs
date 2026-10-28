// Exercises the actual viewer control script with a fake DOM/worker. This is
// not a browser, Android WebView, CSP or security-isolation test.
import assert from 'node:assert/strict';

class Element {
  constructor() { this.disabled = true; this.hidden = false; this.textContent = ''; this.listeners = {}; }
  addEventListener(type, listener) { this.listeners[type] = listener; }
  click() { if (!this.disabled) this.listeners.click(); }
}
const elements = Object.fromEntries(['previous', 'next', 'position', 'status', 'document'].map((id) => [id, new Element()]));
globalThis.document = { getElementById: (id) => elements[id] };
globalThis.window = { addEventListener() {} };
globalThis.fetch = async (url) => url === './name'
  ? new Response('example.pptx')
  : new Response(new Uint8Array([1, 2, 3]));
class FakeWorker {
  constructor(url, options) { this.url = url; this.options = options; this.sent = []; globalThis.lastWorker = this; }
  postMessage(message) { this.sent.push(message); }
  terminate() { this.terminated = true; }
  emit(data) { this.onmessage({ data }); }
}
globalThis.Worker = FakeWorker;
await import('../android/app/src/main/assets/office_engine/viewer.js');
await new Promise((resolve) => setTimeout(resolve, 0));
const worker = globalThis.lastWorker;
assert.equal(worker.url, './worker.js');
assert.equal(worker.options.type, 'module');
assert.equal(worker.sent[0].kind, 'open');
assert.equal(worker.sent[0].name, 'example.pptx');
worker.emit({ kind: 'opened', truncated: false, views: [{ name: 'Slide 1', cut: false }, { name: 'Slide 2', cut: true }] });
assert.deepEqual(worker.sent[1], { kind: 'render', position: 0 });
assert.equal(elements.next.disabled, true);
worker.emit({ kind: 'rendered', position: 0, html: '<p>first</p>', missingResources: false });
assert.equal(elements.document.srcdoc, '<p>first</p>');
assert.equal(elements.document.hidden, false);
assert.equal(elements.position.textContent, '1 / 2');
assert.equal(elements.previous.disabled, true);
assert.equal(elements.next.disabled, false);
elements.next.click();
assert.deepEqual(worker.sent[2], { kind: 'render', position: 1 });
worker.emit({ kind: 'rendered', position: 1, html: '<p>second</p>', missingResources: true });
assert.match(elements.status.textContent, /rows or columns were omitted/);
assert.match(elements.status.textContent, /media or linked resources/);
assert.equal(elements.position.textContent, '2 / 2');
assert.equal(elements.previous.disabled, false);
assert.equal(elements.next.disabled, true);
worker.emit({ kind: 'error', text: 'Could not render' });
assert.equal(elements.status.textContent, 'Could not render');
assert.equal(elements.document.hidden, true);
assert.equal(worker.terminated, true);
console.log('Office viewer control-script test passed with fake DOM/worker (not Android/browser isolation).');
