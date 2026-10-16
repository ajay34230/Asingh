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
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Lets phones running LocalDrop on the same network find each other (mDNS / Android NSD). */
final class Discovery {
    interface Listener { void onChange(); }

    private static final String TYPE = "_localdrop._tcp.";
    private static final String TAG = "LocalDropNsd";

    private static final class Peer {
        String service; String name; String host; int port;
    }

    private final NsdManager nsd;
    private final Map<String, Peer> peers = new ConcurrentHashMap<>();
    private final ArrayDeque<NsdServiceInfo> queue = new ArrayDeque<>();
    private boolean resolving;
    private volatile String myName = "";
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

    void start(int port, String deviceName) {
        if (nsd == null) return;
        try {
            NsdServiceInfo info = new NsdServiceInfo();
            info.setServiceName("LocalDrop " + (deviceName == null ? "phone" : deviceName));
            info.setServiceType(TYPE);
            info.setPort(port);
            try { info.setAttribute("n", deviceName == null ? "" : deviceName); } catch (Throwable ignored) { /* optional */ }
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
                                byte[] n = r.getAttributes().get("n");
                                if (n != null && n.length > 0) p.name = new String(n, "UTF-8");
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
                o.put("url", "http://" + p.host + ":" + p.port + "/");
                a.put(o);
            }
        } catch (Exception ignored) { /* empty list */ }
        return a.toString();
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
