import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Enumeration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * Finds other LocalDrop devices without anyone typing an address. Each computer shouts a short UDP message on every
 * network it is on (works on Wi-Fi, a switch, and a plain cable between two PCs, even with no DHCP), listens for the same
 * from others, and also probes neighbouring address ranges so devices behind other routers are found too.
 */
final class PeerFinder {
    static final int BEACON_PORT = 45454;

    static final class Peer {
        String id = "", name = "", host = "", kind = "desktop";
        int port, tls;
        boolean auto = true, mutual = true, scanned;
        long last;
        Set<String> seen = Collections.<String>emptySet();
    }

    private static final String[] COMMON = {"192.168.0", "192.168.1", "192.168.2", "192.168.3", "192.168.4", "192.168.5",
        "192.168.8", "192.168.10", "192.168.43", "192.168.49", "192.168.100", "192.168.178", "10.0.0", "10.0.1", "10.1.1",
        "10.10.10", "172.16.0", "172.20.10"};

    private final String id;
    private final String name;
    private final int port, tls;
    private final Map<String, Peer> peers = new ConcurrentHashMap<>();
    private volatile boolean running = true;

    PeerFinder(File dataDir, String name, int port, int tls) {
        this.id = loadId(dataDir);
        this.name = name;
        this.port = port;
        this.tls = tls;
        daemon("ld-beacon-send", new Runnable() { public void run() { sendLoop(); } });
        daemon("ld-beacon-recv", new Runnable() { public void run() { recvLoop(); } });
        daemon("ld-scan", new Runnable() { public void run() { scanLoop(); } });
    }

    String id() { return id; }

    void stop() { running = false; }

    private static String loadId(File dir) {
        File f = new File(dir, "room.id");
        try {
            if (f.isFile()) {
                String s = new String(Files.readAllBytes(f.toPath()), StandardCharsets.UTF_8).trim();
                if (s.length() >= 8) return s;
            }
        } catch (Exception ignored) { /* make a new one */ }
        String id = String.format("0000%06x", new java.util.Random().nextInt(0xffffff));
        try { dir.mkdirs(); Files.write(f.toPath(), id.getBytes(StandardCharsets.UTF_8)); } catch (Exception ignored) { /* not saved */ }
        return id;
    }

    private static void daemon(String n, Runnable r) {
        Thread t = new Thread(r, n);
        t.setDaemon(true);
        t.start();
    }

    private static void sleep(long ms) { try { Thread.sleep(ms); } catch (InterruptedException ignored) { /* stopping */ } }

    // ---------------------------------------------------------------- UDP beacon

    private List<InetAddress> broadcasts() {
        List<InetAddress> out = new ArrayList<>();
        try {
            Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces();
            while (en != null && en.hasMoreElements()) {
                NetworkInterface ni = en.nextElement();
                if (!ni.isUp() || ni.isLoopback()) continue;
                for (InterfaceAddress ia : ni.getInterfaceAddresses()) {
                    if (ia.getAddress() instanceof Inet4Address && ia.getBroadcast() != null) out.add(ia.getBroadcast());
                }
            }
        } catch (Exception ignored) { /* none */ }
        return out;
    }

    private void sendLoop() {
        try (DatagramSocket so = new DatagramSocket()) {
            so.setBroadcast(true);
            while (running) {
                byte[] b = ("LDROOM1|" + id + "|" + name.replace('|', ' ') + "|" + port + "|" + tls + "|desktop").getBytes(StandardCharsets.UTF_8);
                List<InetAddress> to = broadcasts();
                try { to.add(InetAddress.getByName("255.255.255.255")); } catch (Exception ignored) { /* no */ }
                for (InetAddress a : to) {
                    try { so.send(new DatagramPacket(b, b.length, a, BEACON_PORT)); } catch (Exception ignored) { /* this network is gone */ }
                }
                sleep(2000);
            }
        } catch (Exception e) {
            System.err.println("beacon send: " + e);
        }
    }

    private boolean isMine(InetAddress a) {
        try { return a.isLoopbackAddress() || NetworkInterface.getByInetAddress(a) != null; } catch (Exception e) { return false; }
    }

    private void recvLoop() {
        try (DatagramSocket so = new DatagramSocket(null)) {
            so.setReuseAddress(true);
            so.bind(new InetSocketAddress(BEACON_PORT));
            byte[] buf = new byte[512];
            while (running) {
                DatagramPacket p = new DatagramPacket(buf, buf.length);
                so.receive(p);
                String[] f = new String(p.getData(), 0, p.getLength(), StandardCharsets.UTF_8).split("\\|");
                if (f.length < 5 || !f[0].equals("LDROOM1") || f[1].equals(id) || isMine(p.getAddress())) continue;
                Peer q = new Peer();
                q.id = f[1];
                q.name = f[2];
                q.host = p.getAddress().getHostAddress();
                q.port = Integer.parseInt(f[3]);
                q.tls = Integer.parseInt(f[4]);
                q.kind = f.length > 5 ? f[5] : "desktop";
                q.last = System.currentTimeMillis();
                peers.put("b:" + q.id, q);
            }
        } catch (Exception e) {
            System.err.println("beacon listen: " + e);
        }
    }

    // ---------------------------------------------------------------- probing other address ranges

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
        } catch (Exception ignored) { /* none */ }
        return out;
    }

    private void scanLoop() {
        int round = 0;
        sleep(3000);
        while (running) {
            try {
                List<String> own = ownPrefixes();
                List<String> t = new ArrayList<>();
                for (String p : own) for (int i = 1; i < 255; i++) t.add(p + "." + i);
                if (round % 6 == 0) {
                    for (String p : COMMON) if (!own.contains(p)) for (int i = 1; i < 255; i++) t.add(p + "." + i);
                }
                for (Peer p : peers.values()) if (p.scanned) t.add(0, p.host);
                final long started = System.currentTimeMillis();
                ExecutorService ex = Executors.newFixedThreadPool(48);
                for (final String h : t) {
                    ex.execute(new Runnable() { public void run() { probe(h, 8080); if (port != 8080) probe(h, port); } });
                }
                ex.shutdown();
                ex.awaitTermination(120, TimeUnit.SECONDS);
                for (Map.Entry<String, Peer> e : peers.entrySet()) {
                    Peer p = e.getValue();
                    if (p.scanned && p.last < started - 5000L) peers.remove(e.getKey());
                }
            } catch (Exception ignored) { /* try again next round */ }
            round++;
            sleep(20000);
        }
    }

    private void probe(String host, int pt) {
        if (!running) return;
        try (Socket so = new Socket()) {
            so.connect(new InetSocketAddress(host, pt), 350);
            so.setSoTimeout(1500);
            so.getOutputStream().write(("GET /api/info HTTP/1.0\r\nHost: " + host + "\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.UTF_8));
            InputStream in = so.getInputStream();
            ByteArrayOutputStream bo = new ByteArrayOutputStream();
            byte[] buf = new byte[2048];
            int n;
            while ((n = in.read(buf)) > 0 && bo.size() < 16384) bo.write(buf, 0, n);
            String all = bo.toString("UTF-8");
            int at = all.indexOf("\r\n\r\n");
            if (at < 0) return;
            Map<String, Object> o = com.ajay.localdrop.server.Json.parseObject(all.substring(at + 4));
            if (!"LocalDrop".equals(o.get("app")) || !(o.get("room") instanceof Map)) return;
            Map<?, ?> room = (Map<?, ?>) o.get("room");
            String pid = String.valueOf(room.get("self"));
            if (pid.isEmpty() || pid.equals(id)) return;
            for (Peer q : peers.values()) if (!q.scanned && pid.equals(q.id)) return;
            Peer p = new Peer();
            p.scanned = true;
            p.id = pid;
            p.host = host;
            p.port = pt;
            p.tls = o.get("tlsPort") instanceof Number ? ((Number) o.get("tlsPort")).intValue() : 0;
            p.name = String.valueOf(o.get("hostName"));
            p.kind = "phone".equals(o.get("platform")) ? "phone" : "desktop";
            p.auto = !Boolean.FALSE.equals(room.get("on"));
            p.last = System.currentTimeMillis();
            java.util.HashSet<String> seen = new java.util.HashSet<>();
            if (room.get("seen") instanceof List) for (Object x : (List<?>) room.get("seen")) seen.add(String.valueOf(x));
            p.seen = seen;
            p.mutual = seen.contains(id);
            peers.put("s:" + host, p);
        } catch (Exception ignored) {
            // nothing LocalDrop here
        }
    }

    // ---------------------------------------------------------------- answers for the page

    private List<Peer> live() {
        long now = System.currentTimeMillis();
        List<Peer> out = new ArrayList<>();
        for (Map.Entry<String, Peer> e : peers.entrySet()) {
            Peer p = e.getValue();
            if (!p.scanned && now - p.last > 9000L) { peers.remove(e.getKey()); continue; }
            out.add(p);
        }
        return out;
    }

    List<Map<String, Object>> nearby() {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Peer p : live()) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("name", p.name);
            m.put("kind", p.kind);
            m.put("host", p.host);
            m.put("port", p.port);
            m.put("id", p.id);
            m.put("url", "http://" + p.host + ":" + p.port + "/");
            if (p.tls > 0) m.put("tlsUrl", "https://" + p.host + ":" + p.tls + "/");
            out.add(m);
        }
        return out;
    }

    /** The shared room: the lowest id wins, except a device that can't see us at all, which we must go to. */
    Map<String, Object> room() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("on", true);
        m.put("self", id);
        String best = id, oneWay = null;
        Peer lead = null, oneWayLead = null;
        List<String> seen = new ArrayList<>();
        for (Peer p : live()) {
            seen.add(p.id);
            if (!p.auto || p.id.isEmpty()) continue;
            if (p.id.compareTo(best) < 0) { best = p.id; lead = p; }
            if (!p.mutual && (oneWay == null || p.id.compareTo(oneWay) < 0)) { oneWay = p.id; oneWayLead = p; }
        }
        if (oneWayLead != null) { best = oneWay; lead = oneWayLead; }
        m.put("seen", seen);
        Map<String, Object> l = new LinkedHashMap<>();
        l.put("id", best);
        l.put("self", lead == null);
        l.put("name", lead == null ? name : lead.name);
        if (lead != null) {
            l.put("url", "http://" + lead.host + ":" + lead.port + "/");
            if (lead.tls > 0) l.put("tlsUrl", "https://" + lead.host + ":" + lead.tls + "/");
        }
        m.put("leader", l);
        return m;
    }
}
