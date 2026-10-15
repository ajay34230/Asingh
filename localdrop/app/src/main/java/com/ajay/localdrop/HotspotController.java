package com.ajay.localdrop;

import android.content.Context;
import android.net.wifi.SoftApConfiguration;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;

import org.json.JSONObject;

/**
 * Starts a private Wi-Fi network from this phone for devices that have no shared Wi-Fi.
 * Android allows an app to do this without turning on the system hotspot; the network has no internet access.
 */
final class HotspotController {
    private static HotspotController instance;

    static synchronized HotspotController get(Context c) {
        if (instance == null) instance = new HotspotController(c.getApplicationContext());
        return instance;
    }

    private final Context ctx;
    private WifiManager.LocalOnlyHotspotReservation reservation;
    private String ssid;
    private String password;
    private String error;
    private boolean starting;
    private Runnable onChange;

    private HotspotController(Context c) {
        ctx = c;
    }

    synchronized void setOnChange(Runnable r) {
        onChange = r;
    }

    private void changed() {
        Runnable r;
        synchronized (this) { r = onChange; }
        if (r != null) r.run();
    }

    synchronized void fail(String message) {
        error = message;
        starting = false;
        changed();
    }

    void start() {
        synchronized (this) {
            if (reservation != null || starting) return;
            starting = true;
            error = null;
        }
        changed();
        try {
            WifiManager wm = (WifiManager) ctx.getSystemService(Context.WIFI_SERVICE);
            wm.startLocalOnlyHotspot(new WifiManager.LocalOnlyHotspotCallback() {
                @Override public void onStarted(WifiManager.LocalOnlyHotspotReservation r) {
                    synchronized (HotspotController.this) {
                        reservation = r;
                        starting = false;
                        read(r);
                    }
                    changed();
                }

                @Override public void onStopped() {
                    synchronized (HotspotController.this) {
                        reservation = null;
                        ssid = null;
                        password = null;
                        starting = false;
                    }
                    changed();
                }

                @Override public void onFailed(int reason) {
                    fail(describe(reason));
                }
            }, new Handler(Looper.getMainLooper()));
        } catch (SecurityException e) {
            fail("Allow nearby devices or location access, then try again.");
        } catch (Exception e) {
            fail("This phone could not start a hotspot. Turn on your phone's own hotspot in Settings instead.");
        }
    }

    void stop() {
        WifiManager.LocalOnlyHotspotReservation r;
        synchronized (this) {
            r = reservation;
            reservation = null;
            ssid = null;
            password = null;
            starting = false;
        }
        if (r != null) {
            try { r.close(); } catch (Exception ignored) { }
        }
        changed();
    }

    private void read(WifiManager.LocalOnlyHotspotReservation r) {
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                SoftApConfiguration c = r.getSoftApConfiguration();
                ssid = c.getSsid();
                password = c.getPassphrase();
            } else {
                WifiConfiguration c = r.getWifiConfiguration();
                ssid = c.SSID;
                password = c.preSharedKey;
            }
            ssid = unquote(ssid);
            password = unquote(password);
        } catch (Exception e) {
            error = "The hotspot started, but its name could not be read.";
        }
    }

    private static String unquote(String s) {
        if (s != null && s.length() >= 2 && s.startsWith("\"") && s.endsWith("\"")) return s.substring(1, s.length() - 1);
        return s;
    }

    private static String describe(int reason) {
        switch (reason) {
            case WifiManager.LocalOnlyHotspotCallback.ERROR_NO_CHANNEL:
                return "No Wi-Fi channel is free right now. Turn off Wi-Fi tethering and try again.";
            case WifiManager.LocalOnlyHotspotCallback.ERROR_INCOMPATIBLE_MODE:
                return "Your phone's hotspot or Wi-Fi Direct is already in use. Turn it off and try again.";
            case WifiManager.LocalOnlyHotspotCallback.ERROR_TETHERING_DISALLOWED:
                return "Hotspots are blocked on this phone.";
            default:
                return "The hotspot could not start. Make sure location is turned on, then try again.";
        }
    }

    synchronized String stateJson() {
        try {
            JSONObject o = new JSONObject();
            o.put("running", reservation != null);
            o.put("starting", starting);
            o.put("ssid", ssid == null ? JSONObject.NULL : ssid);
            o.put("password", password == null ? JSONObject.NULL : password);
            o.put("error", error == null ? JSONObject.NULL : error);
            return o.toString();
        } catch (Exception e) {
            return "{}";
        }
    }
}
