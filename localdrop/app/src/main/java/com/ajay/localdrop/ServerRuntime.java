package com.ajay.localdrop;

import android.content.Context;
import android.content.SharedPreferences;

import com.ajay.localdrop.server.LocalDropServer;

import java.io.IOException;

/** Keeps one server alive for the whole app process, shared by the screen and the foreground service. */
final class ServerRuntime {
    private static LocalDropServer server;
    private static AndroidPlatform platform;

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
        }
        return server;
    }

    static synchronized LocalDropServer get() {
        return server;
    }

    static synchronized AndroidPlatform platform() {
        return platform;
    }

    static synchronized void stop() {
        if (server != null) {
            server.stop();
            server = null;
            platform = null;
        }
    }
}
