package com.ajay.localdrop;

import android.content.Context;
import android.content.SharedPreferences;

import com.ajay.localdrop.server.LocalDropServer;

import java.io.IOException;

/** Keeps one server alive for the whole app process, shared by the screen and the foreground service. */
final class ServerRuntime {
    private static LocalDropServer server;
    private static AndroidPlatform platform;
    private static Discovery discovery;

    private ServerRuntime() {}

    static synchronized LocalDropServer ensure(Context c) throws IOException {
        if (server == null) {
            Context app = c.getApplicationContext();
            AndroidPlatform p = new AndroidPlatform(app);
            LocalDropServer s = new LocalDropServer(p);
            SharedPreferences prefs = app.getSharedPreferences("ld", Context.MODE_PRIVATE);
            s.start(prefs.getInt("port", 8080));
            platform = p;
            server = s;
            try {
                discovery = new Discovery(app);
                discovery.start(installId(app), s.port(), s.tlsPort(), p.deviceName(), autoConnect(app));
            } catch (Throwable ignored) {
                discovery = null;
            }
        }
        return server;
    }

    static synchronized LocalDropServer get() {
        return server;
    }

    static synchronized AndroidPlatform platform() {
        return platform;
    }

    static String installId(Context c) {
        SharedPreferences p = c.getSharedPreferences("ld", Context.MODE_PRIVATE);
        String id = p.getString("installId", "");
        if (id.isEmpty()) {
            id = Long.toHexString(new java.security.SecureRandom().nextLong() & 0xffffffffffL);
            while (id.length() < 10) id = "0" + id;
            p.edit().putString("installId", id).apply();
        }
        return id;
    }

    static boolean autoConnect(Context c) {
        return c.getSharedPreferences("ld", Context.MODE_PRIVATE).getBoolean("autoConnect", true);
    }

    static synchronized Discovery discovery() {
        return discovery;
    }

    static synchronized void stop() {
        if (discovery != null) {
            discovery.stop();
            discovery = null;
        }
        if (server != null) {
            server.stop();
            server = null;
            platform = null;
        }
    }
}
