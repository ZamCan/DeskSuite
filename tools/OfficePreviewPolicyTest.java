package com.zamcan.desksuite;

/** Run with javac/java; independent of the Android SDK. */
public final class OfficePreviewPolicyTest {
    private static void expect(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
    private static String type(String scheme, String host, int port, String user,
                               String path, String query, String method) {
        return OfficePreviewPolicy.allowedType(scheme, host, port, user, path, query, method);
    }
    public static void main(String[] args) {
        String p = OfficePreviewPolicy.PREFIX;
        String h = OfficePreviewPolicy.HOST;
        String[] permitted = {"viewer.html", "viewer.css", "viewer.js", "worker.js",
                "index.js", "odr-core.mjs", "odr-core.wasm", "source", "name"};
        for (String leaf : permitted) {
            expect(type("https", h, -1, null, p + leaf, null, "GET") != null, leaf);
        }
        expect("application/wasm".equals(type("https", h, -1, null, p + "odr-core.wasm", null, "GET")), "WASM MIME");
        expect(type("http", h, -1, null, p + "source", null, "GET") == null, "cleartext");
        expect(type("https", "evil.example", -1, null, p + "source", null, "GET") == null, "external host");
        expect(type("https", h + ".evil.example", -1, null, p + "source", null, "GET") == null, "lookalike host");
        expect(type("https", h, 443, null, p + "source", null, "GET") == null, "explicit port");
        expect(type("https", h, -1, "user", p + "source", null, "GET") == null, "userinfo");
        expect(type("https", h, -1, null, p + "source", "x=1", "GET") == null, "query");
        expect(type("https", h, -1, null, p + "source", null, "POST") == null, "method");
        expect(type("https", h, -1, null, p + "../source", null, "GET") == null, "path traversal");
        expect(type("https", h, -1, null, p + "package.json", null, "GET") == null, "unknown asset");
        expect(type("file", null, -1, null, p + "source", null, "GET") == null, "file access");
        expect(type(null, null, -1, null, null, null, null) == null, "null request");
        System.out.println("Office preview policy tests passed: 9 assets and 11 blocked request cases.");
    }
}
