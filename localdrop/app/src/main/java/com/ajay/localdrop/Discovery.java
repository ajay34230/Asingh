package com.ajay.localdrop;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.Inet4Address;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.ArrayDeque;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Lets phones running LocalDrop on the same network find each other (mDNS / Android NSD). */
final class Discovery {
    interface Listener { void onChange(); }

    private static final String TYPE = "_localdrop._tcp.";
    private static final String TAG = "LocalDropNsd";

    private static final class Peer {
        String service; String name; String host; int port; int tls; String id = ""; boolean auto = true;
        /** Found by scanning other subnets rather than mDNS; seen is the ids that phone itself can see. */
        boolean scanned; boolean mutual = true; long last; java.util.Set<String> seen = new java.util.HashSet<>();
    }

    private final NsdManager nsd;
    private final Map<String, Peer> peers = new ConcurrentHashMap<>();
    private final ArrayDeque<NsdServiceInfo> queue = new ArrayDeque<>();
    private boolean resolving;
    private volatile String myName = "";
    private volatile String myId = "";
    private volatile String myDevice = "";
    private volatile int myPort;
    private volatile int myTls;
    private volatile boolean auto = true;
    private final Map<String, Long> down = new ConcurrentHashMap<>();
    private volatile Listener listener;
    private NsdManager.RegistrationListener reg;
    private NsdManager.DiscoveryListener disc;

    Discovery(Context c) {
        nsd = (NsdManager) c.getSystemService(Context.NSD_SERVICE);
    }

    void setListener(Listener l) { listener = l; }

    private void changed() {
        Listener l = listener;
        if (l != null) l.onChange();
    }

    /** Whether this phone takes part in the automatic shared room (the person can turn it off). */
    void setAuto(boolean on, int port, int tlsPort, String deviceName) {
        if (auto == on) return;
        auto = on;
        stop();
        start(myId, port, tlsPort, deviceName, on);
    }

    void start(String id, int port, int tlsPort, String deviceName, boolean autoConnect) {
        if (nsd == null) return;
        myId = id;
        myPort = port;
        myTls = tlsPort;
        myDevice = deviceName == null ? "" : deviceName;
        auto = autoConnect;
        try {
            NsdServiceInfo info = new NsdServiceInfo();
            info.setServiceName("LocalDrop " + (deviceName == null ? "phone" : deviceName));
            info.setServiceType(TYPE);
            info.setPort(port);
            try {
                info.setAttribute("n", deviceName == null ? "" : deviceName);
                info.setAttribute("i", id);
                info.setAttribute("t", Integer.toString(tlsPort));
                info.setAttribute("a", autoConnect ? "1" : "0");
            } catch (Throwable ignored) { /* optional */ }
            reg = new NsdManager.RegistrationListener() {
                @Override public void onServiceRegistered(NsdServiceInfo i) { myName = i.getServiceName(); }
                @Override public void onRegistrationFailed(NsdServiceInfo i, int code) { Log.w(TAG, "register failed " + code); }
                @Override public void onServiceUnregistered(NsdServiceInfo i) { }
                @Override public void onUnregistrationFailed(NsdServiceInfo i, int code) { }
            };
            nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, reg);
        } catch (Throwable t) {
            Log.w(TAG, "register: " + t);
        }
        try {
            disc = new NsdManager.DiscoveryListener() {
                @Override public void onStartDiscoveryFailed(String t, int code) { Log.w(TAG, "discover failed " + code); }
                @Override public void onStopDiscoveryFailed(String t, int code) { }
                @Override public void onDiscoveryStarted(String t) { }
                @Override public void onDiscoveryStopped(String t) { }
                @Override public void onServiceFound(NsdServiceInfo i) {
                    if (i.getServiceName() == null || i.getServiceName().equals(myName)) return;
                    synchronized (queue) { queue.add(i); }
                    next();
                }
                @Override public void onServiceLost(NsdServiceInfo i) {
                    if (peers.remove(i.getServiceName()) != null) changed();
                }
            };
            nsd.discoverServices(TYPE, NsdManager.PROTOCOL_DNS_SD, disc);
        } catch (Throwable t) {
            Log.w(TAG, "discover: " + t);
        }
        startScan();
    }

    // ---------------------------------------------------------------- scanning (other routers / subnets)

    private volatile boolean scanning;
    private volatile Thread scanThread;
    private static final String[] COMMON = {
        "192.168.0", "192.168.1", "192.168.2", "192.168.3", "192.168.4", "192.168.5", "192.168.8", "192.168.10",
        "192.168.11", "192.168.20", "192.168.29", "192.168.43", "192.168.49", "192.168.50", "192.168.100", "192.168.101",
        "192.168.123", "192.168.178", "192.168.254", "10.0.0", "10.0.1", "10.0.2", "10.1.1", "10.10.10", "10.0.10",
        "172.16.0", "172.20.10", "172.16.1"
    };

    /** Every few seconds, ask the neighbouring addresses whether they run LocalDrop, so phones behind other routers are found too. */
    private void startScan() {
        scanning = true;
        final Thread t = new Thread(new Runnable() {
            @Override public void run() {
                int round = 0;
                while (scanning) {
                    try {
                        scanRound(round % 6 == 0);
                    } catch (Throwable e) {
                        Log.w(TAG, "scan: " + e);
                    }
                    round++;
                    try { Thread.sleep(20000L); } catch (InterruptedException e) { return; }
                }
            }
        }, "ld-scan");
        t.setDaemon(true);
        scanThread = t;
        t.start();
    }

    private List<String> ownPrefixes() {
        List<String> out = new ArrayList<>();
        try {
            Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces();
            while (en != null && en.hasMoreElements()) {
                NetworkInterface ni = en.nextElement();
                if (!ni.isUp() || ni.isLoopback()) continue;
                Enumeration<InetAddress> as = ni.getInetAddresses();
                while (as.hasMoreElements()) {
                    InetAddress a = as.nextElement();
                    if (!(a instanceof Inet4Address) || a.isLoopbackAddress() || a.isLinkLocalAddress()) continue;
                    String ip = a.getHostAddress();
                    String pre = ip.substring(0, ip.lastIndexOf('.'));
                    if (!out.contains(pre)) out.add(pre);
                }
            }
        } catch (Throwable ignored) { /* no interfaces */ }
        return out;
    }

    private void scanRound(boolean wide) throws InterruptedException {
        List<String> own = ownPrefixes();
        if (own.isEmpty()) return;
        List<String> targets = new ArrayList<>();
        for (String pre : own) for (int i = 1; i < 255; i++) targets.add(pre + "." + i);
        if (wide) {
            for (String pre : COMMON) {
                if (own.contains(pre)) continue;
                for (int i = 1; i < 255; i++) targets.add(pre + "." + i);
            }
        }
        // Addresses already known are re-checked first so a phone that went away is dropped quickly.
        List<String> known = new ArrayList<>();
        for (Peer p : peers.values()) if (p.scanned) known.add(p.host);
        int[] ports = myPort == 8080 ? new int[] {8080} : new int[] {8080, myPort};
        ExecutorService ex = Executors.newFixedThreadPool(48);
        final long started = System.currentTimeMillis();
        try {
            for (final String h : known) for (final int pt : ports) ex.execute(new Runnable() { @Override public void run() { probe(h, pt); } });
            for (final String h : targets) {
                if (known.contains(h)) continue;
                for (final int pt : ports) ex.execute(new Runnable() { @Override public void run() { probe(h, pt); } });
            }
        } finally {
            ex.shutdown();
        }
        ex.awaitTermination(90, TimeUnit.SECONDS);
        boolean gone = false;
        for (Map.Entry<String, Peer> e : peers.entrySet()) {
            Peer p = e.getValue();
            if (p.scanned && p.last < started - 5000L) { peers.remove(e.getKey()); gone = true; }
        }
        if (gone) changed();
    }

    private void probe(String host, int port) {
        if (!scanning) return;
        Socket so = new Socket();
        try {
            so.connect(new InetSocketAddress(host, port), 350);
            so.setSoTimeout(1500);
            OutputStream o = so.getOutputStream();
            o.write(("GET /api/info HTTP/1.0\r\nHost: " + host + "\r\nConnection: close\r\n\r\n").getBytes("UTF-8"));
            o.flush();
            InputStream in = so.getInputStream();
            java.io.ByteArrayOutputStream bo = new java.io.ByteArrayOutputStream();
            byte[] buf = new byte[2048];
            int n;
            while ((n = in.read(buf)) > 0 && bo.size() < 16384) bo.write(buf, 0, n);
            String all = bo.toString("UTF-8");
            int at = all.indexOf("\r\n\r\n");
            if (at < 0) return;
            JSONObject o2 = new JSONObject(all.substring(at + 4));
            if (!"LocalDrop".equals(o2.optString("app"))) return;
            JSONObject room = o2.optJSONObject("room");
            if (room == null) return; // a desktop host or an older build: not part of the phone room
            String id = room.optString("self", "");
            if (id.isEmpty() || id.equals(myId)) return;
            for (Peer q : peers.values()) if (!q.scanned && id.equals(q.id)) return; // already found by mDNS
            Peer p = new Peer();
            p.scanned = true;
            p.service = "scan:" + host;
            p.host = host;
            p.port = port;
            p.tls = o2.optInt("tlsPort", 0);
            p.id = id;
            p.name = o2.optString("hostName", host);
            p.auto = room.optBoolean("on", true);
            p.last = System.currentTimeMillis();
            JSONArray sa = room.optJSONArray("seen");
            if (sa != null) for (int i = 0; i < sa.length(); i++) p.seen.add(sa.optString(i));
            p.mutual = p.seen.contains(myId);
            boolean fresh = !peers.containsKey(p.service);
            peers.put(p.service, p);
            if (fresh) changed();
        } catch (Throwable ignored) {
            // nothing LocalDrop here
        } finally {
            try { so.close(); } catch (Throwable ignored) { /* closed */ }
        }
    }

    private void next() {
        final NsdServiceInfo i;
        synchronized (queue) {
            if (resolving) return;
            i = queue.poll();
            if (i == null) return;
            resolving = true;
        }
        try {
            nsd.resolveService(i, new NsdManager.ResolveListener() {
                @Override public void onResolveFailed(NsdServiceInfo r, int code) { done(); }
                @Override public void onServiceResolved(NsdServiceInfo r) {
                    try {
                        InetAddress a = r.getHost();
                        if (a instanceof Inet4Address && NetworkInterface.getByInetAddress(a) == null && !r.getServiceName().equals(myName)) {
                            Peer p = new Peer();
                            p.service = r.getServiceName();
                            p.host = a.getHostAddress();
                            p.port = r.getPort();
                            p.name = p.service.startsWith("LocalDrop ") ? p.service.substring(10) : p.service;
                            try {
                                Map<String, byte[]> at = r.getAttributes();
                                byte[] n = at.get("n");
                                if (n != null && n.length > 0) p.name = new String(n, "UTF-8");
                                byte[] i = at.get("i");
                                if (i != null) p.id = new String(i, "UTF-8");
                                byte[] t = at.get("t");
                                if (t != null) p.tls = Integer.parseInt(new String(t, "UTF-8"));
                                byte[] au = at.get("a");
                                p.auto = au == null || !"0".equals(new String(au, "UTF-8"));
                            } catch (Throwable ignored) { /* use the service name */ }
                            peers.put(p.service, p);
                            changed();
                        }
                    } catch (Throwable ignored) {
                        // skip this one
                    }
                    done();
                }
            });
        } catch (Throwable t) {
            done();
        }
    }

    private void done() {
        synchronized (queue) { resolving = false; }
        next();
    }

    /** Other LocalDrop phones found so far, as JSON for the page. */
    String json() {
        JSONArray a = new JSONArray();
        try {
            for (Peer p : peers.values()) {
                JSONObject o = new JSONObject();
                o.put("name", p.name);
                o.put("host", p.host);
                o.put("port", p.port);
                o.put("id", p.id);
                o.put("url", "http://" + p.host + ":" + p.port + "/");
                if (p.tls > 0) o.put("tlsUrl", "https://" + p.host + ":" + p.tls + "/");
                a.put(o);
            }
        } catch (Exception ignored) { /* empty list */ }
        return a.toString();
    }

    boolean knowsHost(String host) {
        for (Peer p : peers.values()) if (p.host.equals(host)) return true;
        return false;
    }

    /** A peer that didn't answer; skip it when choosing the room host for a minute. */
    void markDown(String id) { if (id != null) down.put(id, System.currentTimeMillis() + 60000L); }

    /**
     * The shared room: every phone with automatic joining on picks the same host, the one with the lowest id,
     * so all of them end up in one place without anyone choosing.
     */
    Map<String, Object> room() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("on", auto);
        m.put("self", myId);
        if (!auto) return m;
        long now = System.currentTimeMillis();
        String best = myId;
        Peer lead = null;
        // A phone behind another router may be reachable one way only (we can reach it, it can't see us).
        // It can't come to us, so we go to it.
        String oneWayBest = null;
        Peer oneWayLead = null;
        for (Peer p : peers.values()) {
            Long until = down.get(p.id);
            if (!p.auto || p.id.isEmpty() || (until != null && until > now)) continue;
            if (p.id.compareTo(best) < 0) { best = p.id; lead = p; }
            if (!p.mutual && (oneWayBest == null || p.id.compareTo(oneWayBest) < 0)) { oneWayBest = p.id; oneWayLead = p; }
        }
        if (oneWayLead != null) { best = oneWayBest; lead = oneWayLead; }
        List<String> seenIds = new ArrayList<>();
        for (Peer p : peers.values()) if (!p.id.isEmpty()) seenIds.add(p.id);
        m.put("seen", seenIds);
        Map<String, Object> l = new LinkedHashMap<>();
        l.put("id", best);
        if (lead == null) {
            l.put("self", true);
            l.put("name", myDevice);
        } else {
            l.put("self", false);
            l.put("name", lead.name);
            l.put("url", "http://" + lead.host + ":" + lead.port + "/");
            if (lead.tls > 0) l.put("tlsUrl", "https://" + lead.host + ":" + lead.tls + "/");
        }
        m.put("leader", l);
        return m;
    }

    String roomJson() {
        try {
            JSONObject o = new JSONObject(room());
            return o.toString();
        } catch (Throwable t) {
            return "{}";
        }
    }

    boolean knows(String url) {
        for (Peer p : peers.values()) if (("http://" + p.host + ":" + p.port + "/").equals(url)) return true;
        return false;
    }

    void stop() {
        scanning = false;
        Thread st = scanThread;
        if (st != null) st.interrupt();
        scanThread = null;
        try { if (reg != null) nsd.unregisterService(reg); } catch (Throwable ignored) { /* already gone */ }
        try { if (disc != null) nsd.stopServiceDiscovery(disc); } catch (Throwable ignored) { /* already gone */ }
        reg = null;
        disc = null;
        peers.clear();
    }
}
