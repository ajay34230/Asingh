package com.ajay.localdrop.server;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TimeZone;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Semaphore;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

import com.ajay.localdrop.server.Http.HttpError;
import com.ajay.localdrop.server.Http.Request;
import com.ajay.localdrop.server.Http.Response;

/** LocalDrop: share files and messages between devices on the same network. */
public final class LocalDropServer {

    public interface Listener {
        void onPeopleChanged();
    }

    private static final class Session {
        boolean host;
        String deviceId;
        String name;
        String kind;
        String ip;
    }

    private final Platform platform;
    private final ScheduledExecutorService timer;
    private final Store store;
    private final Hub hub;
    private final FileStore files;
    private final Http http;
    private final Map<String, long[]> failures = new ConcurrentHashMap<>();
    private final Map<String, byte[]> assets = new ConcurrentHashMap<>();
    private final Semaphore thumbSlots = new Semaphore(2);
    private final AtomicLong msgSeq = new AtomicLong();
    private volatile int port;

    public LocalDropServer(Platform platform) {
        this.platform = platform;
        this.timer = Executors.newScheduledThreadPool(2, new ThreadFactory() {
            @Override public Thread newThread(Runnable r) {
                Thread t = new Thread(r, "ld-timer");
                t.setDaemon(true);
                return t;
            }
        });
        this.store = new Store(platform, timer);
        this.hub = new Hub(timer);
        this.files = new FileStore(platform);
        this.http = new Http(new Http.Handler() {
            @Override public void handle(Request req, Response res) throws Exception { route(req, res); }
        }, platform);

        File r = null;
        if (store.root != null) {
            File c = new File(store.root);
            if (c.isDirectory() && platform.isRootAllowed(c)) r = c;
        }
        if (r == null) r = platform.defaultRoot();
        try {
            files.setRoot(r);
        } catch (IOException e) {
            platform.log("Could not use " + r + ": " + e);
            try {
                files.setRoot(new File(platform.dataDir(), "shared"));
            } catch (IOException e2) {
                throw new IllegalStateException("No usable shared folder", e2);
            }
        }
        store.root = files.root().getPath();
        hub.ensure("host", store.deviceName, platform.deviceKind(), null, true);
        msgSeq.set(System.currentTimeMillis());
    }

    // ---------------------------------------------------------------- lifecycle

    public int start(int preferredPort) throws IOException {
        port = http.start(preferredPort);
        timer.scheduleWithFixedDelay(new Runnable() {
            @Override public void run() {
                store.pruneExpired();
                files.purgeTrash(30);
            }
        }, 5, 3600, TimeUnit.SECONDS);
        return port;
    }

    public void stop() {
        http.stop();
        store.flush();
        timer.shutdownNow();
    }

    public int port() { return port; }
    public void setPinEnabled(boolean on) { store.pinEnabled = on; store.markDirty(); }
    public void setPin(String pin) { store.pin = pin; store.markDirty(); }
    public String pin() { return store.pin; }
    public boolean pinEnabled() { return store.pinEnabled; }
    public int guestsOnline() { return hub.onlineGuests(); }
    public String rootPath() { return files.root().getPath(); }
    public List<Map<String, Object>> addresses() { return NetInfo.addresses(port, platform); }
    public void setListener(final Listener l) {
        hub.setListener(new Hub.Listener() {
            @Override public void onPeopleChanged() { l.onPeopleChanged(); }
        });
    }

    // ---------------------------------------------------------------- session & auth

    private Session session(Request req) {
        if (req.loopback) {
            Session s = new Session();
            s.host = true;
            s.deviceId = "host";
            s.name = store.deviceName;
            s.kind = platform.deviceKind();
            s.ip = req.remoteIp;
            return s;
        }
        Map<String, Object> rec = store.lookupToken(req.cookie("ld"));
        if (rec == null) return null;
        Session s = new Session();
        s.host = false;
        s.deviceId = Json.str(rec, "id");
        s.name = Json.str(rec, "name");
        s.kind = Json.str(rec, "kind");
        if (s.kind == null) s.kind = "other";
        s.ip = req.remoteIp;
        Hub.Device d = hub.get(s.deviceId);
        if (d == null) hub.ensure(s.deviceId, s.name, s.kind, s.ip, false);
        else d.ip = s.ip;
        return s;
    }

    private Session need(Request req) {
        Session s = session(req);
        if (s == null) throw new HttpError(401, "Sign in to continue.");
        return s;
    }

    private static void needHost(Session s) {
        if (!s.host) throw new HttpError(403, "Only the host can do that.");
    }

    private void needUpload(Session s) {
        if (!s.host && !store.guestUpload) throw new HttpError(403, "The host has turned off uploads.");
    }

    private void needModify(Session s) {
        if (!s.host && !store.guestModify) throw new HttpError(403, "The host has turned off changes to files.");
    }

    private static String cleanLabel(String s, int max, String def) {
        if (s == null) return def;
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c >= 0x20 && c != 0x7f) sb.append(c);
        }
        String t = sb.toString().trim();
        if (t.isEmpty()) return def;
        return t.length() > max ? t.substring(0, max).trim() : t;
    }

    private static String cleanKind(String k) {
        if (k == null) return "other";
        switch (k) {
            case "phone": case "tablet": case "laptop": case "desktop": case "tv": return k;
            default: return "other";
        }
    }

    private static String cleanId(String id) {
        if (id != null && id.matches("[A-Za-z0-9-]{8,64}")) return id;
        return "d-" + Store.randomToken(8);
    }

    // ---------------------------------------------------------------- routing

    private void route(Request req, Response res) throws Exception {
        String path = req.path;
        String method = req.method.equals("HEAD") ? "GET" : req.method;
        if (req.loopback) guardLoopback(req);
        if (path.startsWith("/api/")) {
            if (!method.equals("GET")) guardWrite(req);
            api(method, path, req, res);
            return;
        }
        if (path.startsWith("/s/")) {
            if (!method.equals("GET")) throw new HttpError(405, "Method not allowed");
            sharedDownload(req, res);
            return;
        }
        if (method.equals("GET")) {
            staticFile(req, res);
            return;
        }
        throw new HttpError(405, "Method not allowed");
    }

    /** Requests from this very device are trusted as the host, so make sure they come from our own pages. */
    private void guardLoopback(Request req) {
        String host = req.header("host");
        if (host != null) {
            String h = host.toLowerCase(Locale.ROOT);
            int colon = h.lastIndexOf(':');
            String name = h.startsWith("[") ? h.substring(0, h.indexOf(']') + 1) : (colon > 0 ? h.substring(0, colon) : h);
            if (!name.equals("127.0.0.1") && !name.equals("localhost") && !name.equals("[::1]")) {
                throw new HttpError(403, "Open LocalDrop from this device using its own address.");
            }
        }
        String site = req.header("sec-fetch-site");
        if (site != null && site.equals("cross-site")) throw new HttpError(403, "Blocked cross-site request.");
    }

    /** Changes must carry our custom header, which web pages on other sites cannot add without permission. */
    private void guardWrite(Request req) {
        if (!"LocalDrop".equals(req.header("x-requested-with"))) throw new HttpError(403, "Blocked request.");
        String origin = req.header("origin");
        String host = req.header("host");
        if (origin != null && host != null && !origin.endsWith("//" + host)) throw new HttpError(403, "Blocked request.");
    }

    private void api(String m, String path, Request req, Response res) throws Exception {
        switch (path) {
            case "/api/info": info(req, res); return;
            case "/api/ping": res.json(200, Json.obj("t", System.currentTimeMillis())); return;
            case "/api/login": login(req, res); return;
            case "/api/logout": logout(req, res); return;
            default: break;
        }
        Session s = need(req);
        switch (path) {
            case "/api/events": events(s, req, res); return;
            case "/api/devices": res.json(200, hub.deviceList()); return;
            case "/api/device": renameDevice(s, req, res); return;
            case "/api/devices/kick": kick(s, req, res); return;
            case "/api/files": listFiles(s, req, res); return;
            case "/api/search": search(s, req, res); return;
            case "/api/file": download(s, req, res); return;
            case "/api/thumb": thumb(req, res); return;
            case "/api/upload": upload(s, req, res); return;
            case "/api/mkdir": mkdir(s, req, res); return;
            case "/api/rename": rename(s, req, res); return;
            case "/api/move": move(s, req, res); return;
            case "/api/delete": delete(s, req, res); return;
            case "/api/zip": zip(s, req, res); return;
            case "/api/text": text(m, s, req, res); return;
            case "/api/newfile": newFile(s, req, res); return;
            case "/api/trash": res.json(200, files.trashList()); return;
            case "/api/trash/restore": trashRestore(s, req, res); return;
            case "/api/trash/empty": trashEmpty(s, res); return;
            case "/api/storage": res.json(200, files.storage()); return;
            case "/api/share": share(s, req, res); return;
            case "/api/shares": shares(s, res); return;
            case "/api/share/revoke": revokeShare(s, req, res); return;
            case "/api/messages": messages(m, s, req, res); return;
            case "/api/messages/delete": deleteMessage(s, req, res); return;
            case "/api/messages/clear": clearMessages(s, res); return;
            case "/api/activity": res.json(200, hub.recentActivity(100)); return;
            case "/api/admin/settings": adminSettings(m, s, req, res); return;
            case "/api/admin/regen-pin": regenPin(s, res); return;
            case "/api/admin/root": setRoot(s, req, res); return;
            case "/api/admin/network": needHost(s); res.json(200, NetInfo.addresses(port, platform)); return;
            default: throw new HttpError(404, "Not found");
        }
    }

    // ---------------------------------------------------------------- info, login, devices

    private void info(Request req, Response res) throws IOException {
        Session s = session(req);
        Map<String, Object> m = Json.obj("app", "LocalDrop", "version", platform.version(), "platform", platform.deviceKind(),
                "hostName", store.deviceName, "host", req.loopback, "authed", s != null,
                "pinRequired", s == null && store.pinEnabled);
        if (s != null) {
            m.put("you", Json.obj("id", s.deviceId, "name", s.name, "kind", s.kind));
            m.put("perms", perms(s));
            m.put("rootName", files.rootLabel());
            m.put("port", port);
        }
        res.json(200, m);
    }

    private Map<String, Object> perms(Session s) {
        return Json.obj("upload", s.host || store.guestUpload, "modify", s.host || store.guestModify,
                "links", store.allowLinks);
    }

    private void login(Request req, Response res) throws IOException {
        if (!req.method.equals("POST")) throw new HttpError(405, "Method not allowed");
        guardWrite(req);
        Map<String, Object> b = req.json();
        String id = cleanId(Json.str(b, "deviceId"));
        String name = cleanLabel(Json.str(b, "name"), 40, "Device");
        String kind = cleanKind(Json.str(b, "kind"));
        if (req.loopback) {
            res.json(200, Json.obj("ok", true, "host", true, "deviceId", "host"));
            return;
        }
        String ip = req.remoteIp;
        long now = System.currentTimeMillis();
        long[] f = failures.get(ip);
        if (f != null && f[1] > now) {
            long wait = (f[1] - now + 999) / 1000;
            throw new HttpError(429, "Too many wrong PINs. Try again in " + wait + " seconds.");
        }
        if (store.pinEnabled) {
            String pin = Json.str(b, "pin");
            pin = pin == null ? "" : pin.trim();
            if (!Store.constantEquals(pin, store.pin)) {
                long[] r = f == null ? new long[2] : f;
                r[0]++;
                if (r[0] >= 5) {
                    long lock = Math.min(5 * 60000L, 15000L << Math.min(10, (int) (r[0] - 5)));
                    r[1] = now + lock;
                }
                failures.put(ip, r);
                throw new HttpError(401, "That PIN isn't right.");
            }
            failures.remove(ip);
        }
        store.revokeDevice(id);
        String token = store.issueToken(id, name, kind);
        hub.ensure(id, name, kind, ip, false);
        res.cookie("ld=" + token + "; Path=/; HttpOnly; SameSite=Lax; Max-Age=31536000");
        res.json(200, Json.obj("ok", true, "deviceId", id));
    }

    private void logout(Request req, Response res) throws IOException {
        guardWrite(req);
        Session s = session(req);
        if (s != null && !s.host) store.revokeDevice(s.deviceId);
        res.cookie("ld=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0");
        res.json(200, Json.obj("ok", true));
    }

    private void events(Session s, Request req, Response res) throws IOException {
        Hub.Client c = hub.connect(s.deviceId);
        OutputStream o = res.events();
        try {
            o.write("retry: 2500\n\n".getBytes(StandardCharsets.UTF_8));
            Map<String, Object> hello = Json.obj("devices", hub.deviceList(),
                    "you", Json.obj("id", s.deviceId, "name", s.name, "kind", s.kind),
                    "perms", perms(s), "activity", hub.recentActivity(30));
            o.write(Hub.frame("hello", hello).getBytes(StandardCharsets.UTF_8));
            o.flush();
            while (!c.closed && http.isRunning()) {
                String ev = c.queue.poll(15, TimeUnit.SECONDS);
                if (ev != null) o.write(ev.getBytes(StandardCharsets.UTF_8));
                else o.write(": keep-alive\n\n".getBytes(StandardCharsets.UTF_8));
                o.flush();
            }
            String rest;
            while ((rest = c.queue.poll()) != null) o.write(rest.getBytes(StandardCharsets.UTF_8));
            o.flush();
        } catch (InterruptedException ignored) {
            Thread.currentThread().interrupt();
        } finally {
            hub.disconnect(c);
        }
    }

    private void renameDevice(Session s, Request req, Response res) throws IOException {
        Map<String, Object> b = req.json();
        String name = cleanLabel(Json.str(b, "name"), 40, null);
        String kind = Json.str(b, "kind") == null ? null : cleanKind(Json.str(b, "kind"));
        if (name == null) throw new HttpError(400, "Enter a name.");
        if (s.host) {
            store.deviceName = name;
            store.markDirty();
        } else {
            store.renameDevice(s.deviceId, name, kind);
        }
        hub.ensure(s.deviceId, name, kind, null, s.host);
        hub.broadcastDevices();
        res.json(200, Json.obj("ok", true, "name", name));
    }

    private void kick(Session s, Request req, Response res) throws IOException {
        needHost(s);
        String id = Json.str(req.json(), "id");
        if (id == null || id.equals("host")) throw new HttpError(400, "Choose a device.");
        store.revokeDevice(id);
        hub.kick(id);
        res.json(200, Json.obj("ok", true));
    }

    // ---------------------------------------------------------------- files

    private void listFiles(Session s, Request req, Response res) throws IOException {
        File dir = files.resolve(req.q("path"));
        if (!dir.isDirectory()) throw new HttpError(404, "That folder doesn't exist.");
        boolean hidden = "1".equals(req.q("hidden"));
        String rel = files.relOf(dir);
        res.json(200, Json.obj("path", rel, "name", rel.isEmpty() ? files.rootLabel() : dir.getName(),
                "entries", files.list(dir, hidden)));
    }

    private void search(Session s, Request req, Response res) throws IOException {
        String q = req.q("q", "").trim();
        if (q.isEmpty()) {
            res.json(200, Json.obj("entries", new ArrayList<Object>()));
            return;
        }
        File from = files.resolve(req.q("path"));
        if (!from.isDirectory()) throw new HttpError(404, "That folder doesn't exist.");
        res.json(200, Json.obj("entries", files.search(from, q, "1".equals(req.q("hidden")))));
    }

    private static String httpDate(long t) {
        SimpleDateFormat f = new SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", Locale.US);
        f.setTimeZone(TimeZone.getTimeZone("GMT"));
        return f.format(new Date(t));
    }

    private static String pct(String s) {
        try {
            return URLEncoder.encode(s, "UTF-8").replace("+", "%20").replace("*", "%2A");
        } catch (Exception e) {
            return "file";
        }
    }

    static String disposition(String type, String name) {
        StringBuilder ascii = new StringBuilder();
        for (int i = 0; i < name.length(); i++) {
            char c = name.charAt(i);
            ascii.append(c >= 0x20 && c < 0x7f && c != '"' && c != '\\' && c != '%' ? c : '_');
        }
        return type + "; filename=\"" + ascii + "\"; filename*=UTF-8''" + pct(name);
    }

    private void download(Session s, Request req, Response res) throws IOException {
        File f = files.resolve(req.q("path"));
        boolean dl = "1".equals(req.q("dl"));
        serveFile(req, res, f, dl, dl ? s.name : null, dl ? s.deviceId : null);
    }

    private void serveFile(Request req, Response res, File f, boolean download, String who, String whoId)
            throws IOException {
        if (!f.isFile()) throw new HttpError(404, "That file no longer exists.");
        String name = f.getName();
        String mime = Mime.of(name);
        boolean inline = !download && Mime.inlineSafe(mime);
        long len = f.length();
        long mod = f.lastModified();
        String etag = "\"" + Long.toHexString(len) + "-" + Long.toHexString(mod) + "\"";
        res.header("ETag", etag);
        res.header("Last-Modified", httpDate(mod));
        res.header("Accept-Ranges", "bytes");
        res.header("Cache-Control", "private, no-cache");
        String range = req.header("range");
        if (range == null && etag.equals(req.header("if-none-match"))) {
            res.bytes(304, mime, new byte[0]);
            return;
        }
        long start = 0;
        long end = len - 1;
        int status = 200;
        if (range != null && range.startsWith("bytes=") && len > 0) {
            String spec = range.substring(6).trim();
            int comma = spec.indexOf(',');
            if (comma >= 0) spec = spec.substring(0, comma);
            int dash = spec.indexOf('-');
            if (dash >= 0) {
                try {
                    String a = spec.substring(0, dash).trim();
                    String b = spec.substring(dash + 1).trim();
                    long st;
                    long en = len - 1;
                    if (a.isEmpty()) {
                        long n = Long.parseLong(b);
                        st = Math.max(0, len - n);
                    } else {
                        st = Long.parseLong(a);
                        if (!b.isEmpty()) en = Math.min(len - 1, Long.parseLong(b));
                    }
                    if (st > en || st >= len) {
                        res.header("Content-Range", "bytes */" + len);
                        res.error(416, "That range isn't available.");
                        return;
                    }
                    start = st;
                    end = en;
                    status = 206;
                } catch (NumberFormatException ignored) {
                    // ignore a malformed range and send the whole file
                }
            }
        }
        long count = len == 0 ? 0 : end - start + 1;
        String ctype = mime.startsWith("text/") ? mime + "; charset=utf-8" : mime;
        res.header("Content-Disposition", disposition(inline ? "inline" : "attachment", name));
        if (status == 206) res.header("Content-Range", "bytes " + start + "-" + end + "/" + len);
        OutputStream out = res.begin(status, ctype, count);
        long sent = 0;
        try {
            if (!res.isHead() && count > 0) {
                RandomAccessFile raf = new RandomAccessFile(f, "r");
                try {
                    raf.seek(start);
                    byte[] buf = new byte[128 * 1024];
                    long left = count;
                    while (left > 0) {
                        int n = raf.read(buf, 0, (int) Math.min(buf.length, left));
                        if (n < 0) break;
                        out.write(buf, 0, n);
                        left -= n;
                        sent += n;
                    }
                    if (left > 0) res.closeAfter = true;
                } finally {
                    raf.close();
                }
            }
            out.close();
        } finally {
            if (sent > 0) store.addTraffic(0, sent);
        }
        if (who != null && start == 0 && !res.isHead()) {
            hub.addActivity("download", who, whoId, "downloaded " + name, files.relOf(f));
        }
    }

    private void thumb(Request req, Response res) throws IOException {
        File f = files.resolve(req.q("path"));
        if (!f.isFile()) throw new HttpError(404, "Not found");
        int w = 320;
        try { w = Math.max(64, Math.min(1024, Integer.parseInt(req.q("w", "320")))); } catch (NumberFormatException ignored) { }
        String etag = "\"t" + Long.toHexString(f.length()) + "-" + Long.toHexString(f.lastModified()) + "-" + w + "\"";
        res.header("ETag", etag);
        res.header("Cache-Control", "private, max-age=86400");
        if (etag.equals(req.header("if-none-match"))) {
            res.bytes(304, "image/jpeg", new byte[0]);
            return;
        }
        byte[] data = null;
        try {
            thumbSlots.acquire();
            try {
                data = platform.thumbnail(f, w);
            } finally {
                thumbSlots.release();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (RuntimeException e) {
            data = null;
        }
        if (data != null) {
            res.bytes(200, "image/jpeg", data);
            return;
        }
        String mime = Mime.of(f.getName());
        if (mime.startsWith("image/") && !mime.equals("image/svg+xml") && f.length() < 4L * 1024 * 1024) {
            byte[] raw = Files.readAllBytes(f.toPath());
            res.bytes(200, mime, raw);
            return;
        }
        throw new HttpError(404, "No preview");
    }

    private void upload(Session s, Request req, Response res) throws IOException {
        if (!req.method.equals("PUT") && !req.method.equals("POST")) throw new HttpError(405, "Method not allowed");
        needUpload(s);
        if (req.header("content-length") == null) throw new HttpError(411, "Length required");
        File dir = files.resolve(req.q("path"));
        String rel = req.q("rel", "");
        for (String seg : rel.replace('\\', '/').split("/")) {
            if (seg.trim().isEmpty() || seg.equals(".")) continue;
            dir = new File(dir, FileStore.cleanName(seg));
        }
        // the folder (including any subfolders from a folder upload) must stay inside the shared folder
        String canon = dir.getCanonicalPath();
        String rootPath = files.root().getPath();
        if (!canon.equals(rootPath) && !canon.startsWith(rootPath + File.separator)) {
            throw new HttpError(403, "That is outside the shared folder.");
        }
        if (dir.getName().startsWith(FileStore.HIDDEN)) throw new HttpError(403, "That folder is not available.");
        if (!dir.isDirectory() && !dir.mkdirs()) throw new HttpError(500, "Could not create the folder.");
        String name = FileStore.cleanName(req.q("name"));
        long len = req.contentLength;
        long free = dir.getUsableSpace();
        if (free > 0 && len > free - 1024 * 1024) throw new HttpError(507, "There isn't enough free space for this file.");
        File tmp = new File(dir, ".ld-" + Store.randomToken(5) + FileStore.PART);
        long got = 0;
        boolean ok = false;
        try {
            FileOutputStream fo = new FileOutputStream(tmp);
            try {
                byte[] buf = new byte[128 * 1024];
                InputStream in = req.body();
                int n;
                while ((n = in.read(buf)) > 0) {
                    fo.write(buf, 0, n);
                    got += n;
                }
            } finally {
                fo.close();
            }
            if (got != len) throw new IOException("Upload was interrupted");
            File target = null;
            if ("replace".equals(req.q("conflict"))) {
                target = new File(dir, name);
                try {
                    Files.move(tmp.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
                } catch (IOException e) {
                    throw new HttpError(500, "Could not save the file.");
                }
            } else {
                for (int i = 0; i < 10000 && target == null; i++) {
                    String cand = i == 0 ? name : numbered(name, i);
                    File c = new File(dir, cand);
                    try {
                        Files.move(tmp.toPath(), c.toPath());
                        target = c;
                    } catch (FileAlreadyExistsException exists) {
                        // try the next name
                    }
                }
                if (target == null) throw new HttpError(409, "Could not find a free name for this file.");
            }
            ok = true;
            long mt = 0;
            try { mt = Long.parseLong(req.q("mtime", "0")); } catch (NumberFormatException ignored) { }
            if (mt > 946684800000L && mt < System.currentTimeMillis() + 86400000L) {
                //noinspection ResultOfMethodCallIgnored
                target.setLastModified(mt);
            }
            store.addTraffic(got, 0);
            String relPath = files.relOf(target);
            boolean quiet = "1".equals(req.q("quiet"));
            if (!quiet) hub.addActivity("upload", s.name, s.deviceId, "uploaded " + target.getName(), relPath);
            hub.broadcast("files", Json.obj("dir", files.relOf(dir)));
            res.json(200, Json.obj("ok", true, "name", target.getName(), "path", relPath, "size", got));
        } finally {
            if (!ok) {
                if (got > 0) store.addTraffic(got, 0);
                //noinspection ResultOfMethodCallIgnored
                tmp.delete();
            }
        }
    }

    private static String numbered(String name, int i) {
        int dot = name.lastIndexOf('.');
        String base = dot > 0 ? name.substring(0, dot) : name;
        String ext = dot > 0 ? name.substring(dot) : "";
        return base + " (" + i + ")" + ext;
    }

    private void changed(File dir) {
        hub.broadcast("files", Json.obj("dir", files.relOf(dir)));
    }

    private void mkdir(Session s, Request req, Response res) throws IOException {
        needModify(s);
        Map<String, Object> b = req.json();
        File parent = files.resolve(Json.str(b, "path"));
        if (!parent.isDirectory()) throw new HttpError(404, "That folder doesn't exist.");
        File d = files.mkdir(parent, Json.str(b, "name"));
        hub.addActivity("mkdir", s.name, s.deviceId, "created folder " + d.getName(), files.relOf(d));
        changed(parent);
        res.json(200, Json.obj("ok", true, "path", files.relOf(d)));
    }

    private void rename(Session s, Request req, Response res) throws IOException {
        needModify(s);
        Map<String, Object> b = req.json();
        File f = files.resolve(Json.str(b, "path"));
        if (f.equals(files.root())) throw new HttpError(400, "The shared folder itself can't be renamed.");
        String old = f.getName();
        File t = files.rename(f, Json.str(b, "name"));
        hub.addActivity("rename", s.name, s.deviceId, "renamed " + old + " to " + t.getName(), files.relOf(t));
        changed(t.getParentFile());
        res.json(200, Json.obj("ok", true, "path", files.relOf(t)));
    }

    private void move(Session s, Request req, Response res) throws IOException {
        needModify(s);
        Map<String, Object> b = req.json();
        File dest = files.resolve(Json.str(b, "dest"));
        boolean copy = Json.bool(b, "copy", false);
        int n = 0;
        for (Object o : Json.list(b, "paths")) {
            File src = files.resolve(String.valueOf(o));
            if (src.equals(files.root())) continue;
            File parent = src.getParentFile();
            files.moveOrCopy(src, dest, copy);
            n++;
            if (parent != null) changed(parent);
        }
        changed(dest);
        if (n > 0) {
            hub.addActivity(copy ? "copy" : "move", s.name, s.deviceId,
                    (copy ? "copied " : "moved ") + n + (n == 1 ? " item" : " items"), files.relOf(dest));
        }
        res.json(200, Json.obj("ok", true, "count", n));
    }

    private void delete(Session s, Request req, Response res) throws IOException {
        needModify(s);
        Map<String, Object> b = req.json();
        boolean permanent = Json.bool(b, "permanent", false);
        if (permanent) needHost(s);
        int n = 0;
        String last = null;
        for (Object o : Json.list(b, "paths")) {
            File f = files.resolve(String.valueOf(o));
            if (f.equals(files.root())) throw new HttpError(400, "The shared folder itself can't be deleted.");
            if (!f.exists()) continue;
            File parent = f.getParentFile();
            last = f.getName();
            if (permanent) FileStore.deleteTree(f);
            else files.moveToTrash(f);
            n++;
            if (parent != null) changed(parent);
        }
        if (n > 0) {
            hub.addActivity("delete", s.name, s.deviceId, n == 1 ? "deleted " + last : "deleted " + n + " items", null);
        }
        res.json(200, Json.obj("ok", true, "count", n));
    }

    private void zip(Session s, Request req, Response res) throws IOException {
        List<File> items = new ArrayList<>();
        for (String p : req.qAll("path")) {
            File f = files.resolve(p);
            if (f.exists() && !f.equals(files.root())) items.add(f);
            else if (f.equals(files.root())) items.add(f);
        }
        if (items.isEmpty()) throw new HttpError(400, "Choose something to download.");
        String zipName;
        String custom = req.q("name");
        if (custom != null && !custom.trim().isEmpty()) zipName = FileStore.cleanName(custom) + ".zip";
        else if (items.size() == 1) zipName = (items.get(0).equals(files.root()) ? files.rootLabel() : items.get(0).getName()) + ".zip";
        else zipName = "LocalDrop-" + new SimpleDateFormat("yyyyMMdd-HHmm", Locale.US).format(new Date()) + ".zip";
        res.header("Content-Disposition", disposition("attachment", zipName));
        OutputStream out = res.begin(200, "application/zip", -1);
        final long[] sent = {0};
        try {
            if (!res.isHead()) {
                files.zip(items, out, new FileStore.Counter() {
                    @Override public void add(long n) { sent[0] += n; }
                });
            }
            out.close();
        } finally {
            if (sent[0] > 0) store.addTraffic(0, sent[0]);
        }
        hub.addActivity("download", s.name, s.deviceId, "downloaded " + zipName, null);
    }

    private void text(String m, Session s, Request req, Response res) throws IOException {
        if (m.equals("GET")) {
            File f = files.resolve(req.q("path"));
            String content = files.readText(f);
            res.json(200, Json.obj("name", f.getName(), "path", files.relOf(f), "size", f.length(),
                    "mtime", f.lastModified(), "content", content));
            return;
        }
        needModify(s);
        Map<String, Object> b = req.json();
        File f = files.resolve(Json.str(b, "path"));
        if (!f.isFile()) throw new HttpError(404, "That file no longer exists.");
        String content = Json.str(b, "content");
        files.writeText(f, content == null ? "" : content);
        hub.addActivity("edit", s.name, s.deviceId, "edited " + f.getName(), files.relOf(f));
        changed(f.getParentFile());
        res.json(200, Json.obj("ok", true, "mtime", f.lastModified(), "size", f.length()));
    }

    private void newFile(Session s, Request req, Response res) throws IOException {
        needUpload(s);
        Map<String, Object> b = req.json();
        File dir = files.resolve(Json.str(b, "path"));
        if (!dir.isDirectory()) throw new HttpError(404, "That folder doesn't exist.");
        String name = FileStore.cleanName(Json.str(b, "name"));
        File f = new File(dir, FileStore.uniqueName(dir, name));
        String content = Json.str(b, "content");
        files.writeText(f, content == null ? "" : content);
        hub.addActivity("upload", s.name, s.deviceId, "created " + f.getName(), files.relOf(f));
        changed(dir);
        res.json(200, Json.obj("ok", true, "path", files.relOf(f), "name", f.getName()));
    }

    private void trashRestore(Session s, Request req, Response res) throws IOException {
        needModify(s);
        int n = 0;
        for (Object o : Json.list(req.json(), "ids")) {
            String p = files.restore(String.valueOf(o));
            n++;
            File f = files.resolve(p);
            if (f.getParentFile() != null) changed(f.getParentFile());
        }
        if (n > 0) hub.addActivity("restore", s.name, s.deviceId, "restored " + n + (n == 1 ? " item" : " items"), null);
        res.json(200, Json.obj("ok", true, "count", n));
    }

    private void trashEmpty(Session s, Response res) throws IOException {
        needHost(s);
        files.emptyTrash();
        res.json(200, Json.obj("ok", true));
    }

    // ---------------------------------------------------------------- share links

    private void share(Session s, Request req, Response res) throws IOException {
        if (!store.allowLinks) throw new HttpError(403, "Share links are turned off.");
        Map<String, Object> b = req.json();
        File f = files.resolve(Json.str(b, "path"));
        if (!f.exists()) throw new HttpError(404, "That item no longer exists.");
        long hours = Json.num(b, "hours", 24);
        long now = System.currentTimeMillis();
        long expires = hours <= 0 ? 0 : now + Math.min(hours, 24 * 365) * 3600000L;
        String token = Store.randomToken(9);
        String name = f.equals(files.root()) ? files.rootLabel() : f.getName();
        synchronized (store) {
            store.shares.put(token, Json.obj("path", files.relOf(f), "name", name, "dir", f.isDirectory(),
                    "created", now, "expires", expires, "downloads", 0, "by", s.deviceId, "byName", s.name));
            store.markDirty();
        }
        hub.addActivity("share", s.name, s.deviceId, "made a link for " + name, files.relOf(f));
        res.json(200, Json.obj("token", token, "url", "/s/" + token + "/" + pct(name), "expires", expires, "name", name));
    }

    private void shares(Session s, Response res) throws IOException {
        List<Object> out = new ArrayList<>();
        synchronized (store) {
            store.pruneExpired();
            for (Map.Entry<String, Map<String, Object>> e : store.shares.entrySet()) {
                Map<String, Object> v = e.getValue();
                if (!s.host && !s.deviceId.equals(Json.str(v, "by"))) continue;
                Map<String, Object> m = new LinkedHashMap<>(v);
                m.put("token", e.getKey());
                m.put("url", "/s/" + e.getKey() + "/" + pct(String.valueOf(v.get("name"))));
                out.add(m);
            }
        }
        res.json(200, out);
    }

    private void revokeShare(Session s, Request req, Response res) throws IOException {
        String token = Json.str(req.json(), "token");
        synchronized (store) {
            Map<String, Object> v = token == null ? null : store.shares.get(token);
            if (v != null && (s.host || s.deviceId.equals(Json.str(v, "by")))) {
                store.shares.remove(token);
                store.markDirty();
            }
        }
        res.json(200, Json.obj("ok", true));
    }

    private void sharedDownload(Request req, Response res) throws IOException {
        String rest = req.path.substring(3);
        int slash = rest.indexOf('/');
        String token = slash < 0 ? rest : rest.substring(0, slash);
        Map<String, Object> sh;
        synchronized (store) {
            sh = store.shares.get(token);
            if (sh != null) {
                long exp = Json.num(sh, "expires", 0);
                if (exp > 0 && exp < System.currentTimeMillis()) {
                    store.shares.remove(token);
                    store.markDirty();
                    sh = null;
                }
            }
        }
        if (sh == null || !store.allowLinks) throw new HttpError(404, "This link has expired or was removed.");
        File f = files.resolve(Json.str(sh, "path"));
        if (!f.exists()) throw new HttpError(404, "This item is no longer shared.");
        if (req.header("range") == null && !req.method.equals("HEAD")) {
            synchronized (store) {
                sh.put("downloads", Json.num(sh, "downloads", 0) + 1);
                store.markDirty();
            }
            hub.addActivity("download", "Someone", "link", "opened a shared link to " + Json.str(sh, "name"), null);
        }
        if (f.isDirectory()) {
            String zipName = Json.str(sh, "name") + ".zip";
            res.header("Content-Disposition", disposition("attachment", zipName));
            OutputStream out = res.begin(200, "application/zip", -1);
            final long[] sent = {0};
            try {
                if (!res.isHead()) {
                    List<File> one = new ArrayList<>();
                    one.add(f);
                    files.zip(one, out, new FileStore.Counter() {
                        @Override public void add(long n) { sent[0] += n; }
                    });
                }
                out.close();
            } finally {
                if (sent[0] > 0) store.addTraffic(0, sent[0]);
            }
            return;
        }
        serveFile(req, res, f, "1".equals(req.q("dl")), null, null);
    }

    // ---------------------------------------------------------------- messages

    private void messages(String m, Session s, Request req, Response res) throws IOException {
        if (m.equals("GET")) {
            int limit = 200;
            try { limit = Math.max(1, Math.min(500, Integer.parseInt(req.q("limit", "200")))); } catch (NumberFormatException ignored) { }
            res.json(200, store.messagesFor(s.deviceId, s.host, limit));
            return;
        }
        Map<String, Object> b = req.json();
        String text = Json.str(b, "text");
        text = text == null ? "" : text.trim();
        if (text.length() > 8000) throw new HttpError(413, "That message is too long.");
        Object fileRef = b.get("file");
        Map<String, Object> file = null;
        if (fileRef instanceof Map) {
            File f = files.resolve(Json.str(Store.castMap(fileRef), "path"));
            if (!f.isFile()) throw new HttpError(404, "That file no longer exists.");
            file = Json.obj("path", files.relOf(f), "name", f.getName(), "size", f.length(),
                    "mime", Mime.of(f.getName()), "kind", Mime.kind(f.getName()));
        }
        if (text.isEmpty() && file == null) throw new HttpError(400, "Write something or attach a file.");
        String to = Json.str(b, "to");
        if (to != null && to.isEmpty()) to = null;
        if (to != null && hub.get(to) == null) throw new HttpError(404, "That device is not available.");
        Map<String, Object> msg = Json.obj("id", Long.toString(msgSeq.incrementAndGet(), 36), "t", System.currentTimeMillis(),
                "from", Json.obj("id", s.deviceId, "name", s.name, "kind", s.kind), "to", to, "text", text);
        if (file != null) msg.put("file", file);
        store.addMessage(msg);
        if (to == null) {
            hub.broadcast("message", msg);
        } else {
            Set<String> ids = new HashSet<>();
            ids.add(s.deviceId);
            ids.add(to);
            hub.sendTo(ids, "message", msg);
        }
        res.json(200, msg);
    }

    private void deleteMessage(Session s, Request req, Response res) throws IOException {
        String id = Json.str(req.json(), "id");
        Map<String, Object> m = id == null ? null : store.findMessage(id);
        if (m == null) throw new HttpError(404, "That message is already gone.");
        String fromId = Json.str(Store.castMap(m.get("from")), "id");
        if (!s.host && !s.deviceId.equals(fromId)) throw new HttpError(403, "You can only delete your own messages.");
        store.removeMessage(id);
        String to = Json.str(m, "to");
        if (to == null) {
            hub.broadcast("message-delete", Json.obj("id", id));
        } else {
            Set<String> ids = new HashSet<>();
            ids.add(fromId);
            ids.add(to);
            hub.sendTo(ids, "message-delete", Json.obj("id", id));
        }
        res.json(200, Json.obj("ok", true));
    }

    private void clearMessages(Session s, Response res) throws IOException {
        needHost(s);
        store.clearMessages();
        hub.broadcast("messages-cleared", Json.obj("ok", true));
        res.json(200, Json.obj("ok", true));
    }

    // ---------------------------------------------------------------- admin (host only)

    private List<Object> rootsJson() {
        List<Object> out = new ArrayList<>();
        String cur = files.root().getPath();
        for (Platform.RootOption o : platform.rootOptions()) {
            boolean selected = false;
            try { selected = new File(o.path).getCanonicalPath().equals(cur); } catch (IOException ignored) { }
            out.add(Json.obj("id", o.id, "label", o.label, "path", o.path, "note", o.note,
                    "available", o.available, "selected", selected));
        }
        return out;
    }

    private void adminSettings(String m, Session s, Request req, Response res) throws IOException {
        needHost(s);
        if (m.equals("POST")) {
            Map<String, Object> b = req.json();
            boolean revoke = false;
            if (b.containsKey("deviceName")) {
                store.deviceName = cleanLabel(Json.str(b, "deviceName"), 40, store.deviceName);
                hub.ensure("host", store.deviceName, platform.deviceKind(), null, true);
            }
            if (b.containsKey("guestUpload")) store.guestUpload = Json.bool(b, "guestUpload", true);
            if (b.containsKey("guestModify")) store.guestModify = Json.bool(b, "guestModify", true);
            if (b.containsKey("allowLinks")) store.allowLinks = Json.bool(b, "allowLinks", true);
            if (b.containsKey("pinEnabled")) {
                boolean on = Json.bool(b, "pinEnabled", true);
                if (on && !store.pinEnabled) revoke = true;
                store.pinEnabled = on;
            }
            String pin = Json.str(b, "pin");
            if (pin != null && !pin.equals(store.pin)) {
                if (!pin.matches("[0-9]{4,8}")) throw new HttpError(400, "A PIN is 4 to 8 digits.");
                store.pin = pin;
                revoke = true;
            }
            store.markDirty();
            if (revoke) signOutGuests();
            hub.broadcastDevices();
            hub.broadcast("settings", Json.obj("perms", Json.obj("upload", store.guestUpload, "modify", store.guestModify,
                    "links", store.allowLinks)));
        }
        res.json(200, Json.obj("deviceName", store.deviceName, "pinEnabled", store.pinEnabled, "pin", store.pin,
                "guestUpload", store.guestUpload, "guestModify", store.guestModify, "allowLinks", store.allowLinks,
                "roots", rootsJson(), "root", files.root().getPath(), "storage", files.storage(),
                "bytesUp", store.bytesUp, "bytesDown", store.bytesDown, "port", port,
                "version", platform.version(), "platform", platform.deviceKind()));
    }

    private void signOutGuests() {
        store.revokeAll();
        for (Map<String, Object> d : hub.deviceList()) {
            if (!Boolean.TRUE.equals(d.get("host"))) hub.kick(String.valueOf(d.get("id")));
        }
    }

    private void regenPin(Session s, Response res) throws IOException {
        needHost(s);
        store.pin = Store.newPin();
        store.pinEnabled = true;
        store.markDirty();
        signOutGuests();
        res.json(200, Json.obj("pin", store.pin));
    }

    private void setRoot(Session s, Request req, Response res) throws IOException {
        needHost(s);
        Map<String, Object> b = req.json();
        String id = Json.str(b, "id");
        File dir = null;
        if ("custom".equals(id)) {
            String p = Json.str(b, "path");
            if (p != null && !p.trim().isEmpty()) dir = new File(p.trim());
        } else {
            for (Platform.RootOption o : platform.rootOptions()) {
                if (o.id.equals(id)) {
                    if (!o.available) throw new HttpError(409, "Allow access to storage first.");
                    dir = new File(o.path);
                }
            }
        }
        if (dir == null) throw new HttpError(400, "Choose a folder to share.");
        if (!platform.isRootAllowed(dir)) throw new HttpError(403, "That folder can't be shared on this device.");
        try {
            files.setRoot(dir);
        } catch (IOException e) {
            throw new HttpError(400, "That folder can't be used: " + e.getMessage());
        }
        store.root = files.root().getPath();
        store.markDirty();
        hub.broadcast("files", Json.obj("dir", ""));
        hub.broadcast("settings", Json.obj("root", files.rootLabel()));
        res.json(200, Json.obj("ok", true, "root", files.root().getPath()));
    }

    // ---------------------------------------------------------------- static files

    private static String staticType(String name) {
        String e = Mime.ext(name);
        switch (e) {
            case "html": return "text/html; charset=utf-8";
            case "js": return "text/javascript; charset=utf-8";
            case "css": return "text/css; charset=utf-8";
            case "svg": return "image/svg+xml";
            case "webmanifest": return "application/manifest+json";
            case "png": return "image/png";
            case "ico": return "image/x-icon";
            case "json": return "application/json; charset=utf-8";
            default: return "application/octet-stream";
        }
    }

    private void staticFile(Request req, Response res) throws IOException {
        String name = req.path.equals("/") ? "index.html" : req.path.substring(1);
        if (name.equals("favicon.ico")) name = "icon.svg";
        if (!name.matches("[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*") || name.contains("..")) {
            throw new HttpError(404, "Not found");
        }
        byte[] data = assets.get(name);
        if (data == null) {
            InputStream in = platform.openAsset(name);
            if (in == null) throw new HttpError(404, "Not found");
            try {
                ByteArrayOutputStream bo = new ByteArrayOutputStream();
                byte[] buf = new byte[16384];
                int n;
                while ((n = in.read(buf)) > 0) bo.write(buf, 0, n);
                data = bo.toByteArray();
            } finally {
                in.close();
            }
            assets.put(name, data);
        }
        String etag = "\"" + platform.version() + "-" + Integer.toHexString(java.util.Arrays.hashCode(data)) + "\"";
        res.header("ETag", etag);
        res.header("Cache-Control", "no-cache");
        if (name.equals("index.html")) {
            res.header("Content-Security-Policy", "default-src 'self'; img-src 'self' data: blob:; media-src 'self' blob:; "
                    + "style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; frame-src 'self'; "
                    + "object-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'self'");
        }
        if (etag.equals(req.header("if-none-match"))) {
            res.bytes(304, staticType(name), new byte[0]);
            return;
        }
        res.bytes(200, staticType(name), data);
    }
}
