/// Common compressed/input byte limit for local Office and PDF documents.
/// Decoded objects, editor state, PDF split batches and platform pickers can
/// use additional memory; this cap is not a device-memory guarantee.
const int maxDocumentBytes = 48 * 1024 * 1024;
