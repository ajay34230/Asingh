package com.ajay.localdrop.server;

import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/** Finds the addresses other devices can use to reach this one: home Wi-Fi, a hotspot, USB tethering and so on. */
final class NetInfo {
    private NetInfo() {}

    static List<Map<String, Object>> addresses(int port, Platform platform) {
        List<Map<String, Object>> out = new ArrayList<>();
        try {
            Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces();
            while (en != null && en.hasMoreElements()) {
                NetworkInterface ni = en.nextElement();
                try {
                    if (!ni.isUp() || ni.isLoopback()) continue;
                } catch (Exception e) {
                    continue;
                }
                String name = ni.getName().toLowerCase(Locale.ROOT);
                if (skip(name)) continue;
                Enumeration<InetAddress> addrs = ni.getInetAddresses();
                while (addrs.hasMoreElements()) {
                    InetAddress a = addrs.nextElement();
                    if (!(a instanceof Inet4Address) || a.isLinkLocalAddress() || a.isLoopbackAddress()) continue;
                    String ip = a.getHostAddress();
                    String kind = kindOf(name);
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("iface", ni.getName());
                    m.put("kind", kind);
                    m.put("label", label(kind));
                    m.put("ip", ip);
                    m.put("port", port);
                    m.put("url", "http://" + ip + ":" + port);
                    out.add(m);
                }
            }
        } catch (Exception ignored) {
            // no interfaces available
        }
        if (out.isEmpty() && platform != null) {
            try {
                for (String[] pair : platform.fallbackAddresses()) {
                    String name = pair[0] == null ? "" : pair[0].toLowerCase(Locale.ROOT);
                    if (skip(name)) continue;
                    String kind = kindOf(name);
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("iface", pair[0]);
                    m.put("kind", kind);
                    m.put("label", label(kind));
                    m.put("ip", pair[1]);
                    m.put("port", port);
                    m.put("url", "http://" + pair[1] + ":" + port);
                    out.add(m);
                }
            } catch (RuntimeException ignored) {
                // fallback is best effort
            }
        }
        Collections.sort(out, new Comparator<Map<String, Object>>() {
            @Override public int compare(Map<String, Object> a, Map<String, Object> b) {
                return rank(String.valueOf(a.get("kind"))) - rank(String.valueOf(b.get("kind")));
            }
        });
        return out;
    }

    private static boolean skip(String n) {
        return n.startsWith("rmnet") || n.startsWith("ccmni") || n.startsWith("v4-") || n.startsWith("dummy")
                || n.startsWith("docker") || n.startsWith("veth") || n.startsWith("br-") || n.startsWith("virbr")
                || n.startsWith("vmnet") || n.startsWith("vboxnet") || n.startsWith("utun") || n.startsWith("tun")
                || n.startsWith("tap") || n.startsWith("awdl") || n.startsWith("llw") || n.startsWith("lo")
                || n.startsWith("ip6") || n.startsWith("clat") || n.startsWith("ifb");
    }

    private static String kindOf(String n) {
        if (n.startsWith("ap") || n.startsWith("swlan") || n.startsWith("softap") || n.equals("wlan1")
                || n.startsWith("wlan1")) return "hotspot";
        if (n.startsWith("p2p")) return "direct";
        if (n.startsWith("rndis") || n.startsWith("usb")) return "usb";
        if (n.startsWith("wlan") || n.startsWith("wlp") || n.startsWith("wl")) return "wifi";
        if (n.startsWith("eth") || n.startsWith("enp") || n.startsWith("eno") || n.startsWith("ens")) return "ethernet";
        return "other";
    }

    private static String label(String kind) {
        switch (kind) {
            case "hotspot": return "Hotspot";
            case "wifi": return "Wi-Fi";
            case "usb": return "USB tethering";
            case "ethernet": return "Ethernet";
            case "direct": return "Wi-Fi Direct";
            default: return "Network";
        }
    }

    private static int rank(String kind) {
        switch (kind) {
            case "hotspot": return 0;
            case "wifi": return 1;
            case "ethernet": return 2;
            case "usb": return 3;
            case "direct": return 4;
            default: return 9;
        }
    }
}
