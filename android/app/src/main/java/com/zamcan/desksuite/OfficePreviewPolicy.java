package com.zamcan.desksuite;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/** Exact allowlist for the isolated Office preview's local virtual origin. */
final class OfficePreviewPolicy {
    static final String HOST = "appassets.androidplatform.net";
    static final String PREFIX = "/desksuite-office/";
    static final int MAX_SOURCE_BYTES = 8 * 1024 * 1024;
    private static final Map<String, String> TYPES;

    static {
        Map<String, String> types = new HashMap<>();
        types.put("viewer.html", "text/html");
        types.put("viewer.css", "text/css");
        types.put("viewer.js", "text/javascript");
        types.put("worker.js", "text/javascript");
        types.put("index.js", "text/javascript");
        types.put("odr-core.mjs", "text/javascript");
        types.put("odr-core.wasm", "application/wasm");
        types.put("source", "application/octet-stream");
        types.put("name", "text/plain");
        TYPES = Collections.unmodifiableMap(types);
    }

    private OfficePreviewPolicy() {}

    /** Returns a MIME type only for a specific bundled asset or input stream. */
    static String allowedType(String scheme, String host, int port, String userInfo,
                              String path, String query, String method) {
        if (!"https".equals(scheme) || !HOST.equals(host) || port != -1 ||
                userInfo != null || query != null || !"GET".equals(method) ||
                path == null || !path.startsWith(PREFIX)) {
            return null;
        }
        return TYPES.get(path.substring(PREFIX.length()));
    }
}
