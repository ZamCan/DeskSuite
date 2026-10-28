const previous = document.getElementById('previous');
const next = document.getElementById('next');
const position = document.getElementById('position');
const status = document.getElementById('status');
const frame = document.getElementById('document');
const TIMEOUT_MS = 20000;
let worker;
let timer;
let views = [];
let current = 0;
let truncated = false;
let pending = false;

function buttons() {
  previous.disabled = pending || current <= 0;
  next.disabled = pending || current >= views.length - 1;
  position.textContent = views.length ? `${current + 1} / ${views.length}` : '';
}

function fail(message) {
  clearTimeout(timer);
  if (worker) worker.terminate();
  worker = undefined;
  pending = true;
  frame.hidden = true;
  status.textContent = message;
  buttons();
}

function startTimeout() {
  clearTimeout(timer);
  timer = setTimeout(() => fail('This document exceeded the preview time limit. The original was not changed.'), TIMEOUT_MS);
}

function renderView(index) {
  if (!worker || pending || index < 0 || index >= views.length) return;
  current = index;
  pending = true;
  frame.hidden = true;
  status.textContent = `Rendering ${views[index].name}…`;
  buttons();
  startTimeout();
  worker.postMessage({ kind: 'render', position: index });
}

previous.addEventListener('click', () => renderView(current - 1));
next.addEventListener('click', () => renderView(current + 1));
window.addEventListener('pagehide', () => { if (worker) worker.terminate(); });

async function start() {
  try {
    // Both responses are intercepted in memory by the Android host. Nothing
    // here opens a file:// URL or calls a remote service.
    const [source, fileName] = await Promise.all([fetch('./source'), fetch('./name')]);
    if (!source.ok || !fileName.ok) throw new Error('Local source unavailable');
    const bytes = new Uint8Array(await source.arrayBuffer());
    const name = await fileName.text();
    worker = new Worker('./worker.js', { type: 'module' });
    worker.onerror = () => fail('This device could not start the local renderer. Update Android System WebView and try again.');
    worker.onmessage = (event) => {
      const message = event.data || {};
      clearTimeout(timer);
      if (message.kind === 'error') {
        fail(message.text);
      } else if (message.kind === 'opened') {
        views = message.views;
        truncated = message.truncated;
        pending = false;
        renderView(0);
      } else if (message.kind === 'rendered' && message.position === current) {
        // No allow-scripts, allow-same-origin, forms, top navigation or popups.
        // The untrusted result cannot access the outer page or native APIs.
        frame.srcdoc = message.html;
        frame.hidden = false;
        pending = false;
        const warnings = [];
        if (truncated) warnings.push('Only the first 100 views are available.');
        if (views[current].cut) warnings.push('Some spreadsheet rows or columns were omitted by the preview limits.');
        if (message.missingResources) warnings.push('Some media or linked resources are unavailable.');
        status.textContent = warnings.length ? warnings.join(' ') : `${views[current].name} · Read-only preview`;
        buttons();
      }
    };
    pending = true;
    startTimeout();
    worker.postMessage({ kind: 'open', name, bytes }, [bytes.buffer]);
  } catch (error) {
    fail('The local preview could not be started on this device. The original was not changed.');
  }
}
start();
