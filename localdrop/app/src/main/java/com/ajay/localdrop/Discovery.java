package com.ajay.localdrop;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.net.Inet4Address;
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
                                byte[] a = at.get("a");
                                p.auto = a == null || !"0".equals(new String(a, "UTF-8"));
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
        for (Peer p : peers.values()) {
            Long until = down.get(p.id);
            if (!p.auto || p.id.isEmpty() || (until != null && until > now)) continue;
            if (p.id.compareTo(best) < 0) { best = p.id; lead = p; }
        }
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
        try { if (reg != null) nsd.unregisterService(reg); } catch (Throwable ignored) { /* already gone */ }
        try { if (disc != null) nsd.stopServiceDiscovery(disc); } catch (Throwable ignored) { /* already gone */ }
        reg = null;
        disc = null;
        peers.clear();
    }
}
