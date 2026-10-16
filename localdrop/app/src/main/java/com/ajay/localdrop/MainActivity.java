package com.ajay.localdrop;

import android.Manifest;
import android.app.Activity;
import android.app.DownloadManager;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.webkit.ConsoleMessage;
import android.webkit.JavascriptInterface;
import android.webkit.URLUtil;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.IOException;

/** The phone's own screen: a WebView showing the same LocalDrop page that other devices see in their browser. */
public final class MainActivity extends Activity {
    private static final int REQ_FILES = 11;
    private static final int REQ_NOTIFY = 12;
    private static final int REQ_HOTSPOT = 13;
    private static final int REQ_STORAGE = 14;
    private static final int REQ_MEDIA = 15;
    private android.webkit.PermissionRequest mediaRequest;

    private WebView web;
    private ValueCallback<Uri[]> fileCallback;
    private HotspotController hotspot;
    private volatile String origin = "http://127.0.0.1:8080";
    private volatile String pageUrl = "";

    private boolean isPeer(String host) {
        Discovery d = ServerRuntime.discovery();
        return d != null && d.knowsHost(host);
    }

    /** True while the page is LocalDrop's own page on this phone (not another phone's). */
    private boolean local() {
        return pageUrl.startsWith("http://127.0.0.1");
    }
    private boolean pendingHotspot;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        hotspot = HotspotController.get(this);
        web = new WebView(this);
        setContentView(web);
        applyBars(isNight() ? "#07141F" : "#EEF4F6", !isNight());
        web.setBackgroundColor(Color.parseColor(isNight() ? "#07141F" : "#EEF4F6"));
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setTextZoom(100);
        s.setUserAgentString(s.getUserAgentString() + " LocalDropHost/1");
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.addJavascriptInterface(new Bridge(), "LDHost");
        web.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                Uri u = r.getUrl();
                if (u.getHost() != null && (u.getHost().equals("127.0.0.1") || isPeer(u.getHost()))) return false;
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, u));
                } catch (Exception ignored) {
                    // no app can open it
                }
                return true;
            }

            @Override public void onPageStarted(WebView v, String url, android.graphics.Bitmap icon) {
                pageUrl = url == null ? "" : url;
            }

            /** Another LocalDrop phone on this network uses a certificate made by that phone, so accept it for those hosts only. */
            @Override public void onReceivedSslError(WebView v, android.webkit.SslErrorHandler h, android.net.http.SslError e) {
                String host = Uri.parse(e.getUrl()).getHost();
                if (host != null && isPeer(host)) h.proceed(); else h.cancel();
            }

            @Override public boolean onRenderProcessGone(WebView v, android.webkit.RenderProcessGoneDetail d) {
                recreate();
                return true;
            }
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView w, ValueCallback<Uri[]> cb, FileChooserParams p) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = cb;
                try {
                    startActivityForResult(p.createIntent(), REQ_FILES);
                } catch (Exception e) {
                    fileCallback = null;
                    return false;
                }
                return true;
            }

            @Override public void onPermissionRequest(final android.webkit.PermissionRequest r) {
                runOnUiThread(() -> askMedia(r));
            }

            @Override public void onPermissionRequestCanceled(android.webkit.PermissionRequest r) {
                if (mediaRequest == r) mediaRequest = null;
            }

            @Override public boolean onConsoleMessage(ConsoleMessage m) {
                Log.d("LocalDropWeb", m.message() + " (" + m.sourceId() + ":" + m.lineNumber() + ")");
                return true;
            }
        });
        web.setDownloadListener((url, ua, cd, mime, len) -> {
            try {
                String name = URLUtil.guessFileName(url, cd, mime);
                DownloadManager.Request r = new DownloadManager.Request(Uri.parse(url));
                r.setTitle(name);
                String ck = android.webkit.CookieManager.getInstance().getCookie(url);
                if (ck != null) r.addRequestHeader("Cookie", ck);
                r.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                r.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name);
                ((DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE)).enqueue(r);
                Toast.makeText(this, "Saving " + name + " to Downloads", Toast.LENGTH_SHORT).show();
            } catch (Exception e) {
                Toast.makeText(this, "Could not save the file", Toast.LENGTH_SHORT).show();
            }
        });
        hotspot.setOnChange(this::pushChange);
        startServerThenLoad();

        if (Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] {Manifest.permission.POST_NOTIFICATIONS}, REQ_NOTIFY);
        }
    }

    /** Opens the listening socket off the main thread, then loads the page from it. */
    private void startServerThenLoad() {
        final Context app = getApplicationContext();
        new Thread(() -> {
            try {
                final int port = ServerRuntime.ensure(app).port();
                runOnUiThread(() -> {
                    if (isDestroyed() || web == null) return;
                    origin = "http://127.0.0.1:" + port;
                    try {
                        startForegroundService(new Intent(this, ServerService.class));
                    } catch (Exception ignored) {
                        // The server keeps running while the app is open even without the service.
                    }
                    web.loadUrl(origin + "/");
                });
            } catch (Exception e) {
                runOnUiThread(() -> {
                    TextView t = new TextView(this);
                    t.setText("LocalDrop could not start its server.\n\n" + e.getMessage());
                    t.setPadding(48, 96, 48, 48);
                    setContentView(t);
                    web = null;
                });
            }
        }, "ld-start").start();
    }

    private boolean isNight() {
        return (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
                == Configuration.UI_MODE_NIGHT_YES;
    }

    @SuppressWarnings("deprecation")
    private void applyBars(String hex, boolean darkIcons) {
        int c = Color.parseColor(hex);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        getWindow().setStatusBarColor(c);
        getWindow().setNavigationBarColor(c);
        int flags = View.SYSTEM_UI_FLAG_VISIBLE;
        if (darkIcons) {
            flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            if (Build.VERSION.SDK_INT >= 26) flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        }
        getWindow().getDecorView().setSystemUiVisibility(flags);
    }

    /** Lets the page know that something on the phone changed (a permission, the hotspot). */
    private void pushChange() {
        if (web == null) return;
        web.post(() -> web.evaluateJavascript("window.onLDHostChange && window.onLDHostChange()", null));
    }

    @Override protected void onResume() {
        super.onResume();
        Discovery d = ServerRuntime.discovery();
        if (d != null) d.setListener(() -> runOnUiThread(() -> {
            if (web != null) web.evaluateJavascript("window.onLDNearby&&window.onLDNearby()", null);
        }));
        pushChange();
    }

    @Override protected void onPause() {
        Discovery d = ServerRuntime.discovery();
        if (d != null) d.setListener(null);
        super.onPause();
    }

    @Override protected void onDestroy() {
        if (hotspot != null) hotspot.setOnChange(null);
        if (web != null) {
            web.removeJavascriptInterface("LDHost");
            web.destroy();
        }
        super.onDestroy();
    }

    @Override protected void onActivityResult(int req, int result, Intent data) {
        if (req == REQ_FILES) {
            if (fileCallback != null) {
                fileCallback.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(result, data));
                fileCallback = null;
            }
            return;
        }
        super.onActivityResult(req, result, data);
    }

    /** Calls: grant the page the camera or microphone once Android has allowed it. */
    private void askMedia(android.webkit.PermissionRequest r) {
        String oh = r.getOrigin().getHost();
        if (oh == null || !(oh.equals("127.0.0.1") || isPeer(oh))) { r.deny(); return; }
        java.util.List<String> need = new java.util.ArrayList<>();
        for (String res : r.getResources()) {
            if (res.equals(android.webkit.PermissionRequest.RESOURCE_VIDEO_CAPTURE)) need.add(Manifest.permission.CAMERA);
            if (res.equals(android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE)) need.add(Manifest.permission.RECORD_AUDIO);
        }
        java.util.List<String> missing = new java.util.ArrayList<>();
        for (String p : need) if (checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED) missing.add(p);
        if (missing.isEmpty()) { r.grant(r.getResources()); return; }
        if (mediaRequest != null) mediaRequest.deny();
        mediaRequest = r;
        requestPermissions(missing.toArray(new String[0]), REQ_MEDIA);
    }

    @Override public void onRequestPermissionsResult(int req, String[] perms, int[] results) {
        super.onRequestPermissionsResult(req, perms, results);
        if (req == REQ_MEDIA) {
            android.webkit.PermissionRequest r = mediaRequest;
            mediaRequest = null;
            if (r == null) return;
            java.util.List<String> ok = new java.util.ArrayList<>();
            for (String res : r.getResources()) {
                String need = res.equals(android.webkit.PermissionRequest.RESOURCE_VIDEO_CAPTURE) ? Manifest.permission.CAMERA
                    : res.equals(android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE) ? Manifest.permission.RECORD_AUDIO : null;
                if (need != null && checkSelfPermission(need) == PackageManager.PERMISSION_GRANTED) ok.add(res);
            }
            if (ok.isEmpty()) r.deny(); else r.grant(ok.toArray(new String[0]));
            return;
        }
        boolean granted = results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED;
        if (req == REQ_HOTSPOT) {
            if (granted && pendingHotspot) hotspot.start();
            else hotspot.fail("Allow nearby devices access to start a hotspot.");
            pendingHotspot = false;
        }
        pushChange();
    }

    @Override public void onBackPressed() {
        if (web == null) {
            super.onBackPressed();
            return;
        }
        web.evaluateJavascript("window.LDBack ? window.LDBack() : false", value -> {
            if (!"true".equals(value)) moveTaskToBack(true);
        });
    }

    private void startHotspotFlow() {
        String perm = Build.VERSION.SDK_INT >= 33 ? Manifest.permission.NEARBY_WIFI_DEVICES
                : Manifest.permission.ACCESS_FINE_LOCATION;
        if (checkSelfPermission(perm) != PackageManager.PERMISSION_GRANTED) {
            pendingHotspot = true;
            requestPermissions(new String[] {perm}, REQ_HOTSPOT);
            return;
        }
        hotspot.start();
    }

    private void openStorageSettings() {
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                startActivity(new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:" + getPackageName())));
            } catch (Exception e) {
                try {
                    startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
                } catch (Exception ignored) {
                    Toast.makeText(this, "Open Settings and allow all files access for LocalDrop", Toast.LENGTH_LONG).show();
                }
            }
        } else {
            requestPermissions(new String[] {Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQ_STORAGE);
        }
    }

    /** Functions the LocalDrop page can call when it runs on the phone itself. */
    private final class Bridge {
        @JavascriptInterface public String info() {
            try {
                AndroidPlatform p = ServerRuntime.platform();
                JSONObject o = new JSONObject();
                o.put("sdk", Build.VERSION.SDK_INT);
                o.put("storageAccess", p != null && p.hasStorageAccess());
                o.put("notifications", Build.VERSION.SDK_INT < 33
                        || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED);
                PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
                o.put("batteryUnrestricted", pm.isIgnoringBatteryOptimizations(getPackageName()));
                o.put("hotspot", new JSONObject(hotspot.stateJson()));
                o.put("installId", ServerRuntime.installId(getApplicationContext()));
                o.put("deviceName", p == null ? "Phone" : p.deviceName());
                return o.toString();
            } catch (Exception e) {
                return "{}";
            }
        }

        @JavascriptInterface public void requestStorage() {
            if (!local()) return;
            runOnUiThread(MainActivity.this::openStorageSettings);
        }

        @JavascriptInterface public void startHotspot() {
            if (!local()) return;
            runOnUiThread(MainActivity.this::startHotspotFlow);
        }

        @JavascriptInterface public void stopHotspot() {
            if (!local()) return;
            hotspot.stop();
        }

        @JavascriptInterface public void requestNotifications() {
            runOnUiThread(() -> {
                if (Build.VERSION.SDK_INT >= 33) {
                    requestPermissions(new String[] {Manifest.permission.POST_NOTIFICATIONS}, REQ_NOTIFY);
                }
            });
        }

        @JavascriptInterface public void keepRunning() {
            if (!local()) return;
            runOnUiThread(() -> {
                try {
                    startActivity(new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:" + getPackageName())));
                } catch (Exception e) {
                    try {
                        startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS));
                    } catch (Exception ignored) {
                        // no settings screen available
                    }
                }
            });
        }

        @JavascriptInterface public void audioMode(boolean call, boolean speaker) {
            runOnUiThread(() -> {
                try {
                    android.media.AudioManager am = (android.media.AudioManager) getSystemService(Context.AUDIO_SERVICE);
                    am.setMode(call ? android.media.AudioManager.MODE_IN_COMMUNICATION : android.media.AudioManager.MODE_NORMAL);
                    am.setSpeakerphoneOn(call && speaker);
                } catch (Exception ignored) {
                    // audio routing is best effort
                }
            });
        }

        /** The shared room: which phone hosts it, and whether this one takes part. */
        @JavascriptInterface public String room() {
            Discovery d = ServerRuntime.discovery();
            return d == null ? "{}" : d.roomJson();
        }

        @JavascriptInterface public void peerDown(String id) {
            Discovery d = ServerRuntime.discovery();
            if (d != null) d.markDown(id);
        }

        @JavascriptInterface public boolean autoConnect() {
            return ServerRuntime.autoConnect(getApplicationContext());
        }

        @JavascriptInterface public void setAutoConnect(boolean on) {
            Context c = getApplicationContext();
            c.getSharedPreferences("ld", Context.MODE_PRIVATE).edit().putBoolean("autoConnect", on).apply();
            Discovery d = ServerRuntime.discovery();
            com.ajay.localdrop.server.LocalDropServer sv = ServerRuntime.get();
            AndroidPlatform p = ServerRuntime.platform();
            if (d != null && sv != null && p != null) d.setAuto(on, sv.port(), sv.tlsPort(), p.deviceName());
        }

        /** This phone's own LocalDrop page. */
        @JavascriptInterface public String home() {
            return origin + "/";
        }

        @JavascriptInterface public String nearby() {
            Discovery d = ServerRuntime.discovery();
            return d == null ? "[]" : d.json();
        }

        /** Opens another LocalDrop phone found on this network in the browser. */
        @JavascriptInterface public void join(String url) {
            Discovery d = ServerRuntime.discovery();
            if (d == null || url == null || !d.knows(url)) return;
            runOnUiThread(() -> {
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                } catch (Exception e) {
                    Toast.makeText(MainActivity.this, "No browser found", Toast.LENGTH_SHORT).show();
                }
            });
        }

        @JavascriptInterface public void share(String text) {
            runOnUiThread(() -> {
                Intent i = new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text);
                startActivity(Intent.createChooser(i, "Share link"));
            });
        }

        @JavascriptInterface public void copy(String text) {
            runOnUiThread(() -> {
                ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                cm.setPrimaryClip(ClipData.newPlainText("LocalDrop", text));
            });
        }

        @JavascriptInterface public void openExternal(String path) {
            runOnUiThread(() -> {
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(origin + path)));
                } catch (Exception e) {
                    Toast.makeText(MainActivity.this, "No app can open this", Toast.LENGTH_SHORT).show();
                }
            });
        }

        @JavascriptInterface public void bars(String hex, boolean darkIcons) {
            runOnUiThread(() -> {
                try {
                    applyBars(hex, darkIcons);
                } catch (Exception ignored) {
                    // ignore a bad colour
                }
            });
        }

        @JavascriptInterface public void quit() {
            if (!local()) return;
            runOnUiThread(() -> {
                startService(new Intent(MainActivity.this, ServerService.class).setAction(ServerService.ACTION_STOP));
                finishAndRemoveTask();
            });
        }
    }
}
