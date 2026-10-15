package com.ajay.localdrop.server;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/** Who is connected, the live event streams that keep every screen in sync, and the recent activity feed. */
final class Hub {

    static final class Device {
        String id;
        String name;
        String kind;
        String ip;
        boolean host;
        boolean online;
        long lastSeen;
        int connections;
    }

    static final class Client {
        final String deviceId;
        final LinkedBlockingQueue<String> queue = new LinkedBlockingQueue<>();
        volatile boolean closed;

        Client(String deviceId) {
            this.deviceId = deviceId;
        }
    }

    interface Listener {
        void onPeopleChanged();
    }

    private final Map<String, Device> devices = new ConcurrentHashMap<>();
    private final Set<Client> clients = ConcurrentHashMap.newKeySet();
    private final List<Map<String, Object>> activity = new ArrayList<>();
    private final AtomicLong seq = new AtomicLong();
    private final ScheduledExecutorService timer;
    private volatile Listener listener;

    Hub(ScheduledExecutorService timer) {
        this.timer = timer;
    }

    void setListener(Listener l) {
        listener = l;
    }

    static String frame(String event, Object data) {
        return "event: " + event + "\ndata: " + Json.stringify(data) + "\n\n";
    }

    synchronized Device ensure(String id, String name, String kind, String ip, boolean host) {
        Device d = devices.get(id);
        if (d == null) {
            d = new Device();
            d.id = id;
            devices.put(id, d);
        }
        if (name != null && !name.isEmpty()) d.name = name;
        if (kind != null && !kind.isEmpty()) d.kind = kind;
        if (ip != null) d.ip = ip;
        d.host = host;
        if (d.name == null) d.name = "Device";
        if (d.kind == null) d.kind = "other";
        if (host) d.online = true;
        d.lastSeen = System.currentTimeMillis();
        return d;
    }

    synchronized Device get(String id) {
        return devices.get(id);
    }

    Client connect(String deviceId) {
        Client c = new Client(deviceId);
        boolean cameOnline = false;
        synchronized (this) {
            Device d = devices.get(deviceId);
            if (d != null) {
                d.connections++;
                d.lastSeen = System.currentTimeMillis();
                if (!d.online) {
                    d.online = true;
                    cameOnline = true;
                }
            }
            clients.add(c);
        }
        if (cameOnline) {
            Device d = get(deviceId);
            if (d != null) addActivity("join", d.name, d.id, "joined", null);
            broadcastDevices();
        }
        fireChanged();
        return c;
    }

    void disconnect(final Client c) {
        c.closed = true;
        clients.remove(c);
        synchronized (this) {
            Device d = devices.get(c.deviceId);
            if (d != null && d.connections > 0) d.connections--;
        }
        timer.schedule(new Runnable() {
            @Override public void run() {
                boolean wentOffline = false;
                String name = null;
                synchronized (Hub.this) {
                    Device d = devices.get(c.deviceId);
                    if (d != null && !d.host && d.connections <= 0 && d.online) {
                        d.online = false;
                        d.lastSeen = System.currentTimeMillis();
                        wentOffline = true;
                        name = d.name;
                    }
                }
                if (wentOffline) {
                    addActivity("leave", name, c.deviceId, "left", null);
                    broadcastDevices();
                    fireChanged();
                }
            }
        }, 6, TimeUnit.SECONDS);
    }

    private void fireChanged() {
        Listener l = listener;
        if (l != null) {
            try { l.onPeopleChanged(); } catch (RuntimeException ignored) { }
        }
    }

    int onlineGuests() {
        int n = 0;
        for (Device d : devices.values()) if (!d.host && d.online) n++;
        return n;
    }

    void broadcast(String event, Object data) {
        String f = frame(event, data);
        for (Client c : clients) push(c, f);
    }

    void sendTo(Collection<String> ids, String event, Object data) {
        String f = frame(event, data);
        for (Client c : clients) if (ids.contains(c.deviceId)) push(c, f);
    }

    private void push(Client c, String f) {
        if (c.closed) return;
        if (c.queue.size() > 400) {
            c.closed = true;
            return;
        }
        c.queue.offer(f);
    }

    void broadcastDevices() {
        broadcast("devices", deviceList());
    }

    synchronized List<Map<String, Object>> deviceList() {
        List<Device> all = new ArrayList<>(devices.values());
        final long cutoff = System.currentTimeMillis() - 24L * 3600 * 1000;
        List<Device> keep = new ArrayList<>();
        for (Device d : all) if (d.host || d.online || d.lastSeen > cutoff) keep.add(d);
        Collections.sort(keep, new Comparator<Device>() {
            @Override public int compare(Device a, Device b) {
                if (a.host != b.host) return a.host ? -1 : 1;
                if (a.online != b.online) return a.online ? -1 : 1;
                return a.name.compareToIgnoreCase(b.name);
            }
        });
        List<Map<String, Object>> out = new ArrayList<>();
        for (Device d : keep) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", d.id);
            m.put("name", d.name);
            m.put("kind", d.kind);
            m.put("host", d.host);
            m.put("online", d.online);
            m.put("lastSeen", d.lastSeen);
            m.put("ip", d.host ? null : d.ip);
            out.add(m);
        }
        return out;
    }

    /** Tells a device it has been removed, then drops its event streams. */
    void kick(String deviceId) {
        String f = frame("kicked", Json.obj("id", deviceId));
        for (Client c : clients) {
            if (c.deviceId.equals(deviceId)) {
                c.queue.offer(f);
                c.closed = true;
            }
        }
        synchronized (this) {
            Device d = devices.get(deviceId);
            if (d != null && !d.host) {
                d.online = false;
                d.connections = 0;
                d.lastSeen = System.currentTimeMillis();
            }
        }
        broadcastDevices();
        fireChanged();
    }

    synchronized void forget(String deviceId) {
        Device d = devices.get(deviceId);
        if (d != null && !d.host) devices.remove(deviceId);
    }

    // ---- activity feed

    void addActivity(String type, String who, String whoId, String text, String path) {
        Map<String, Object> a = new LinkedHashMap<>();
        a.put("id", seq.incrementAndGet());
        a.put("t", System.currentTimeMillis());
        a.put("type", type);
        a.put("who", who);
        a.put("whoId", whoId);
        a.put("text", text);
        if (path != null) a.put("path", path);
        synchronized (activity) {
            activity.add(a);
            while (activity.size() > 200) activity.remove(0);
        }
        broadcast("activity", a);
    }

    List<Map<String, Object>> recentActivity(int limit) {
        synchronized (activity) {
            int from = Math.max(0, activity.size() - limit);
            return new ArrayList<>(activity.subList(from, activity.size()));
        }
    }
}
