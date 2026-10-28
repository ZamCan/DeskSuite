package com.zamcan.desksuite;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.view.Gravity;
import android.view.View;
import android.webkit.GeolocationPermissions;
import android.webkit.PermissionRequest;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/**
 * An experimental read-only platform view, not the application shell. The
 * document bytes stay in memory. There is no JavaScript interface. Requests
 * not answered from the exact local allowlist fail closed. Device verification
 * of WebView isolation and interception is required before enabling by default.
 */
public final class OfficePreviewFactory extends PlatformViewFactory {
    public static final String VIEW_TYPE = "com.zamcan.desksuite/office-preview";
    private static final String ORIGIN = "https://" + OfficePreviewPolicy.HOST;
    private static final String URL = ORIGIN + OfficePreviewPolicy.PREFIX + "viewer.html";
    private static final String CSP = "default-src 'none'; "
            + "script-src 'self' 'wasm-unsafe-eval'; "
            + "worker-src 'self'; connect-src 'self'; frame-src 'self'; "
            + "style-src 'self' 'unsafe-inline'; img-src data:; font-src data:; "
            + "media-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'";

    public OfficePreviewFactory() {
        super(StandardMessageCodec.INSTANCE);
    }

    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        Map<?, ?> params = args instanceof Map ? (Map<?, ?>) args : null;
        Object source = params == null ? null : params.get("bytes");
        Object name = params == null ? null : params.get("name");
        if (!(source instanceof byte[]) || ((byte[]) source).length == 0 ||
                ((byte[]) source).length > OfficePreviewPolicy.MAX_SOURCE_BYTES ||
                !(name instanceof String)) {
            return new ErrorView(context, "This file cannot be opened within the preview size limit.");
        }
        try {
            return new PreviewView(context, (byte[]) source, (String) name);
        } catch (RuntimeException error) {
            return new ErrorView(context, "The local preview is unavailable on this device.");
        }
    }

    private static TextView message(Context context, String text) {
        TextView view = new TextView(context);
        view.setText(text);
        view.setTextColor(Color.rgb(16, 41, 79));
        view.setTextSize(16);
        view.setGravity(Gravity.CENTER);
        int padding = (int) (24 * context.getResources().getDisplayMetrics().density);
        view.setPadding(padding, padding, padding, padding);
        return view;
    }

    private static final class ErrorView implements PlatformView {
        private final View view;
        ErrorView(Context context, String text) { view = message(context, text); }
        @Override public View getView() { return view; }
        @Override public void dispose() {}
    }

    private static final class PreviewView implements PlatformView {
        private final Context context;
        private final FrameLayout root;
        private WebView web;
        private volatile byte[] source;
        private final byte[] name;

        PreviewView(Context context, byte[] source, String name) {
            this.context = context;
            this.source = source;
            this.name = name.substring(0, Math.min(name.length(), 255)).getBytes(StandardCharsets.UTF_8);
            root = new FrameLayout(context);
            web = new WebView(context);
            WebSettings settings = web.getSettings();
            settings.setJavaScriptEnabled(true); // Trusted local host/worker only.
            settings.setAllowFileAccess(false);
            settings.setAllowContentAccess(false);
            settings.setAllowFileAccessFromFileURLs(false);
            settings.setAllowUniversalAccessFromFileURLs(false);
            settings.setBlockNetworkLoads(true);
            settings.setDomStorageEnabled(false);
            settings.setDatabaseEnabled(false);
            settings.setGeolocationEnabled(false);
            settings.setJavaScriptCanOpenWindowsAutomatically(false);
            settings.setSupportMultipleWindows(false);
            settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
            settings.setCacheMode(WebSettings.LOAD_NO_CACHE);
            settings.setBuiltInZoomControls(true);
            settings.setDisplayZoomControls(false);
            settings.setMediaPlaybackRequiresUserGesture(true);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // This isolated viewer has no network or external navigations.
                settings.setSafeBrowsingEnabled(false);
            }
            web.setWebChromeClient(new WebChromeClient() {
                @Override public void onPermissionRequest(PermissionRequest request) { request.deny(); }
                @Override public void onGeolocationPermissionsShowPrompt(
                        String origin, GeolocationPermissions.Callback callback) {
                    callback.invoke(origin, false, false);
                }
            });
            web.setWebViewClient(new LocalClient());
            root.addView(web, new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
            web.loadUrl(URL);
        }

        @Override public View getView() { return root; }

        @Override public void dispose() {
            source = null;
            destroyWeb();
        }

        private void destroyWeb() {
            if (web != null) {
                WebView old = web;
                web = null;
                root.removeView(old);
                old.stopLoading();
                old.destroy();
            }
        }

        private void showFailure() {
            source = null;
            destroyWeb();
            root.removeAllViews();
            root.addView(message(context,
                    "The local preview could not be opened. Try a smaller file or update Android System WebView. Your original was not changed."));
        }

        private final class LocalClient extends WebViewClient {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                // The only main-page navigation is our programmatic loadUrl.
                return true;
            }

            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String type = OfficePreviewPolicy.allowedType(uri.getScheme(), uri.getHost(),
                        uri.getPort(), uri.getUserInfo(), uri.getPath(), uri.getQuery(), request.getMethod());
                if (type == null) return response("text/plain", 403, "Blocked", new ByteArrayInputStream(new byte[0]));
                String leaf = uri.getPath().substring(OfficePreviewPolicy.PREFIX.length());
                if (leaf.equals("source")) {
                    byte[] bytes = source;
                    if (bytes == null) return response("text/plain", 410, "Gone", new ByteArrayInputStream(new byte[0]));
                    return response(type, 200, "OK", new ByteArrayInputStream(bytes));
                }
                if (leaf.equals("name")) return response(type, 200, "OK", new ByteArrayInputStream(name));
                try {
                    InputStream file = context.getAssets().open("office_engine/" + leaf);
                    return response(type, 200, "OK", file);
                } catch (IOException error) {
                    return response("text/plain", 404, "Not Found", new ByteArrayInputStream(new byte[0]));
                }
            }

            @Override public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) showFailure();
            }

            @TargetApi(26)
            @Override public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
                showFailure();
                return true;
            }
        }
    }

    private static WebResourceResponse response(String type, int status, String reason, InputStream body) {
        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Security-Policy", CSP);
        headers.put("Cache-Control", "no-store");
        headers.put("X-Content-Type-Options", "nosniff");
        String encoding = type.startsWith("text/") ? "UTF-8" : null;
        return new WebResourceResponse(type, encoding, status, reason, headers, body);
    }
}
