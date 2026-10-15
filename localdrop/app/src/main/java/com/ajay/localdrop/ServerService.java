package com.ajay.localdrop;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.drawable.Icon;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

import com.ajay.localdrop.server.LocalDropServer;

import java.util.List;
import java.util.Map;

/** Keeps LocalDrop running when the screen is off or the app is in the background. */
public final class ServerService extends Service {
    static final String ACTION_STOP = "com.ajay.localdrop.STOP";
    private static final String CHANNEL = "server";
    private static final int NOTIFICATION_ID = 1;

    private PowerManager.WakeLock wake;
    private WifiManager.WifiLock wifi;
    private boolean foreground;

    @Override public IBinder onBind(Intent intent) {
        return null;
    }

    @Override public void onCreate() {
        super.onCreate();
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        NotificationChannel ch = new NotificationChannel(CHANNEL, getString(R.string.channel_name),
                NotificationManager.IMPORTANCE_LOW);
        ch.setShowBadge(false);
        nm.createNotificationChannel(ch);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            ServerRuntime.stop();
            release();
            stopForeground(true);
            stopSelf();
            return START_NOT_STICKY;
        }
        LocalDropServer server;
        try {
            server = ServerRuntime.ensure(this);
        } catch (Exception e) {
            stopSelf();
            return START_NOT_STICKY;
        }
        server.setListener(new LocalDropServer.Listener() {
            @Override public void onPeopleChanged() { refresh(); }
        });
        try {
            Notification n = build();
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
            } else {
                startForeground(NOTIFICATION_ID, n);
            }
            foreground = true;
        } catch (Exception e) {
            // The system refused to start a foreground service (for example from the background).
            stopSelf();
            return START_NOT_STICKY;
        }
        acquire();
        return START_STICKY;
    }

    private void refresh() {
        if (!foreground) return;
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        nm.notify(NOTIFICATION_ID, build());
    }

    private Notification build() {
        LocalDropServer s = ServerRuntime.get();
        String text = "Starting";
        if (s != null) {
            List<Map<String, Object>> addrs = s.addresses();
            String url = addrs.isEmpty() ? "Connect to Wi-Fi or start a hotspot" : String.valueOf(addrs.get(0).get("url"));
            int n = s.guestsOnline();
            text = url + (n > 0 ? "  (" + n + (n == 1 ? " device" : " devices") + " connected)" : "");
        }
        PendingIntent open = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        Intent stop = new Intent(this, ServerService.class).setAction(ACTION_STOP);
        PendingIntent stopPi = PendingIntent.getService(this, 1, stop,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        Notification.Builder b = new Notification.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_notify)
                .setContentTitle(getString(R.string.notif_title))
                .setContentText(text)
                .setContentIntent(open)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .addAction(new Notification.Action.Builder(Icon.createWithResource(this, R.drawable.ic_stat_notify),
                        getString(R.string.notif_stop), stopPi).build());
        return b.build();
    }

    @SuppressWarnings("WakelockTimeout")
    private void acquire() {
        try {
            if (wake == null) {
                PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
                wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LocalDrop:server");
                wake.setReferenceCounted(false);
            }
            if (!wake.isHeld()) wake.acquire();
            if (wifi == null) {
                WifiManager wm = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
                int mode = Build.VERSION.SDK_INT >= 29 ? WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                        : WifiManager.WIFI_MODE_FULL_HIGH_PERF;
                wifi = wm.createWifiLock(mode, "LocalDrop:wifi");
                wifi.setReferenceCounted(false);
            }
            if (!wifi.isHeld()) wifi.acquire();
        } catch (Exception ignored) {
            // locks are a nice-to-have
        }
    }

    private void release() {
        try {
            if (wake != null && wake.isHeld()) wake.release();
            if (wifi != null && wifi.isHeld()) wifi.release();
        } catch (Exception ignored) {
            // already released
        }
    }

    @Override public void onDestroy() {
        release();
        super.onDestroy();
    }
}
