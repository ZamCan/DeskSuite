// Read-only OpenDocument.core worker. It never fetches document resources and
// does not run the HTML it generates. The Android host serves these files from
// a local-only virtual origin; the UI renders the result in a sandboxed frame.
import { Odr } from './index.js';

const MAX_SOURCE_BYTES = 8 * 1024 * 1024;
const MAX_HTML_CHARACTERS = 8 * 1024 * 1024;
const MAX_VIEWS = 100;
let engine;
let doc;
let views = [];

function closeDocument() {
  if (doc) {
    try { doc.close(); } finally { doc = undefined; }
  }
  views = [];
}

function selectViews(all) {
  // The library's first view is an aggregate. Prefer separate sheet/slide
  // views when present; a Word document normally has just its document view.
  const pages = all.filter((view) => /^(?:sheet|slide)\d+\.html$/.test(view.path));
  return pages.length ? pages : all;
}

function errorText(error) {
  if (error && error.name === 'PasswordProtected') {
    return 'Password-protected documents are not supported in this preview.';
  }
  if (error && error.name === 'UnsupportedFileType') {
    return 'The renderer cannot read this document format.';
  }
  return 'This file could not be rendered within the preview limits. The original was not changed.';
}

self.onmessage = async (event) => {
  const message = event.data || {};
  try {
    if (message.kind === 'open') {
      closeDocument();
      const bytes = message.bytes;
      if (!(bytes instanceof Uint8Array) || bytes.byteLength === 0 || bytes.byteLength > MAX_SOURCE_BYTES) {
        throw new Error('Source size outside preview bounds');
      }
      engine ||= await Odr.load();
      doc = engine.open(bytes, {
        name: typeof message.name === 'string' ? message.name.slice(0, 255) : '',
        editable: false,
        embedImages: true,
        allowExternalContent: false,
        lazyLayout: false,
        spreadsheetLimit: { rows: 5000, columns: 200 },
        spreadsheetCellLimit: 50000,
        spreadsheetStyleBuffer: 4 * 1024 * 1024,
      });
      if (doc.isPasswordEncrypted()) {
        const error = new Error('Password protected');
        error.name = 'PasswordProtected';
        throw error;
      }
      const types = engine.enums.FileType;
      const allowed = [types.doc, types.docx, types.xls, types.xlsx, types.ppt,
        types.pptx, types.odt, types.ods, types.odp];
      if (!allowed.includes(doc.fileType)) {
        const error = new Error('Not a supported office document');
        error.name = 'UnsupportedFileType';
        throw error;
      }
      const all = selectViews(doc.listViews());
      if (!all.length) throw new Error('No document views');
      views = all.slice(0, MAX_VIEWS);
      self.postMessage({
        kind: 'opened',
        truncated: all.length > views.length,
        views: views.map((view, index) => ({
          name: view.name || `View ${index + 1}`,
          cut: Boolean(view.sheetCut),
        })),
      });
    } else if (message.kind === 'render') {
      if (!doc || !Number.isInteger(message.position) || !views[message.position]) {
        throw new Error('Invalid view');
      }
      const result = doc.render(views[message.position].index);
      if (typeof result.html !== 'string' || result.html.length > MAX_HTML_CHARACTERS) {
        throw new Error('Rendered view exceeds limit');
      }
      self.postMessage({
        kind: 'rendered',
        position: message.position,
        html: result.html,
        missingResources: result.externalResources.length > 0,
      });
    } else if (message.kind === 'close') {
      closeDocument();
    } else {
      throw new Error('Unknown request');
    }
  } catch (error) {
    closeDocument();
    self.postMessage({ kind: 'error', text: errorText(error) });
  }
};
