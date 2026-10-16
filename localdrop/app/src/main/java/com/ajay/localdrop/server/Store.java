package com.ajay.localdrop.server;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/** Settings, sign-in tokens, share links and chat history, saved as small JSON files in the app's private folder. */
final class Store {
    static final int MAX_MESSAGES = 1000;
    private static final SecureRandom RNG = new SecureRandom();

    private final File dir;
    private final ScheduledExecutorService timer;
    private final Platform platform;
    private boolean dirty;
    private boolean scheduled;

    // Settings
    String deviceName;
    boolean pinEnabled = true;
    String pin;
    boolean guestUpload = true;
    boolean guestModify = true;
    boolean allowLinks = true;
    boolean shareApps = false;
    boolean autoTrust = true;
    String root;
    long bytesUp;
    long bytesDown;

    /** Hashed token to {id, name, created, last}. */
    final Map<String, Map<String, Object>> tokens = new LinkedHashMap<>();
    /** Share token to {path, name, dir, created, expires, downloads, by}. */
    final Map<String, Map<String, Object>> shares = new LinkedHashMap<>();
    final List<Map<String, Object>> messages = new ArrayList<>();

    Store(Platform platform, ScheduledExecutorService timer) {
        this.platform = platform;
        this.dir = platform.dataDir();
        this.timer = timer;
        //noinspection ResultOfMethodCallIgnored
        dir.mkdirs();
        load();
    }

    static String randomToken(int bytes) {
        byte[] b = new byte[bytes];
        RNG.nextBytes(b);
        StringBuilder sb = new StringBuilder();
        for (byte x : b) sb.append(String.format("%02x", x & 0xff));
        return sb.toString();
    }

    static String newPin() {
        return String.format("%06d", RNG.nextInt(1000000));
    }

    static String sha256(String s) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] d = md.digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte x : d) sb.append(String.format("%02x", x & 0xff));
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    static boolean constantEquals(String a, String b) {
        if (a == null || b == null) return false;
        return MessageDigest.isEqual(a.getBytes(StandardCharsets.UTF_8), b.getBytes(StandardCharsets.UTF_8));
    }

    private File file(String n) {
        return new File(dir, n);
    }

    private void load() {
        try {
            File f = file("state.json");
            if (f.exists()) {
                Map<String, Object> m = Json.parseObject(new String(Files.readAllBytes(f.toPath()), StandardCharsets.UTF_8));
                deviceName = Json.str(m, "deviceName");
                pinEnabled = Json.bool(m, "pinEnabled", true);
                pin = Json.str(m, "pin");
                guestUpload = Json.bool(m, "guestUpload", true);
                guestModify = Json.bool(m, "guestModify", true);
                allowLinks = Json.bool(m, "allowLinks", true);
                shareApps = Json.bool(m, "shareApps", false);
                autoTrust = Json.bool(m, "autoTrust", true);
                root = Json.str(m, "root");
                bytesUp = Json.num(m, "bytesUp", 0);
                bytesDown = Json.num(m, "bytesDown", 0);
                readMapOfMaps(m.get("tokens"), tokens);
                readMapOfMaps(m.get("shares"), shares);
            }
        } catch (Exception e) {
            platform.log("Could not read settings, starting fresh: " + e);
        }
        try {
            File f = file("messages.json");
            if (f.exists()) {
                Object o = Json.parse(new String(Files.readAllBytes(f.toPath()), StandardCharsets.UTF_8));
                if (o instanceof List) {
                    for (Object x : (List<?>) o) {
                        if (x instanceof Map) {
                            @SuppressWarnings("unchecked") Map<String, Object> mm = (Map<String, Object>) x;
                            messages.add(mm);
                        }
                    }
                }
            }
        } catch (Exception e) {
            platform.log("Could not read messages: " + e);
        }
        if (pin == null || pin.length() != 6) pin = newPin();
        if (deviceName == null || deviceName.trim().isEmpty()) deviceName = platform.deviceName();
        pruneExpired();
    }

    @SuppressWarnings("unchecked")
    private static void readMapOfMaps(Object o, Map<String, Map<String, Object>> into) {
        if (!(o instanceof Map)) return;
        for (Map.Entry<?, ?> e : ((Map<?, ?>) o).entrySet()) {
            if (e.getValue() instanceof Map) into.put(String.valueOf(e.getKey()), (Map<String, Object>) e.getValue());
        }
    }

    synchronized void pruneExpired() {
        long now = System.currentTimeMillis();
        Iterator<Map<String, Object>> it = shares.values().iterator();
        while (it.hasNext()) {
            long exp = Json.num(it.next(), "expires", 0);
            if (exp > 0 && exp < now) it.remove();
        }
    }

    synchronized void markDirty() {
        dirty = true;
        if (scheduled) return;
        scheduled = true;
        timer.schedule(new Runnable() {
            @Override public void run() { flush(); }
        }, 700, TimeUnit.MILLISECONDS);
    }

    synchronized void flush() {
        scheduled = false;
        if (!dirty) return;
        dirty = false;
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("deviceName", deviceName);
        m.put("pinEnabled", pinEnabled);
        m.put("pin", pin);
        m.put("guestUpload", guestUpload);
        m.put("guestModify", guestModify);
        m.put("allowLinks", allowLinks);
        m.put("shareApps", shareApps);
        m.put("autoTrust", autoTrust);
        m.put("root", root);
        m.put("bytesUp", bytesUp);
        m.put("bytesDown", bytesDown);
        m.put("tokens", tokens);
        m.put("shares", shares);
        writeAtomic(file("state.json"), Json.stringify(m));
        writeAtomic(file("messages.json"), Json.stringify(messages));
    }

    private void writeAtomic(File target, String content) {
        try {
            File tmp = new File(target.getParentFile(), target.getName() + ".tmp");
            try (FileOutputStream fo = new FileOutputStream(tmp)) {
                fo.write(content.getBytes(StandardCharsets.UTF_8));
                fo.getFD().sync();
            }
            if (!tmp.renameTo(target)) {
                Files.copy(tmp.toPath(), target.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
                //noinspection ResultOfMethodCallIgnored
                tmp.delete();
            }
        } catch (IOException e) {
            platform.log("Could not save " + target.getName() + ": " + e);
        }
    }

    synchronized void addTraffic(long up, long down) {
        bytesUp += up;
        bytesDown += down;
        markDirty();
    }

    // ---- tokens

    synchronized void renameDevice(String deviceId, String name, String kind) {
        for (Map<String, Object> rec : tokens.values()) {
            if (deviceId.equals(Json.str(rec, "id"))) {
                rec.put("name", name);
                if (kind != null) rec.put("kind", kind);
            }
        }
        markDirty();
    }

    synchronized String issueToken(String deviceId, String name, String kind) {
        String token = randomToken(24);
        Map<String, Object> rec = Json.obj("id", deviceId, "name", name, "kind", kind,
                "created", System.currentTimeMillis(), "last", System.currentTimeMillis());
        tokens.put(sha256(token), rec);
        // Keep the table from growing without bound.
        while (tokens.size() > 200) {
            Iterator<String> it = tokens.keySet().iterator();
            it.next();
            it.remove();
        }
        markDirty();
        return token;
    }

    synchronized Map<String, Object> lookupToken(String token) {
        if (token == null || token.isEmpty()) return null;
        return tokens.get(sha256(token));
    }

    synchronized int revokeDevice(String deviceId) {
        int n = 0;
        Iterator<Map<String, Object>> it = tokens.values().iterator();
        while (it.hasNext()) {
            if (deviceId.equals(Json.str(it.next(), "id"))) {
                it.remove();
                n++;
            }
        }
        if (n > 0) markDirty();
        return n;
    }

    synchronized void revokeAll() {
        tokens.clear();
        markDirty();
    }

    // ---- messages

    synchronized void addMessage(Map<String, Object> msg) {
        messages.add(msg);
        while (messages.size() > MAX_MESSAGES) messages.remove(0);
        markDirty();
    }

    synchronized boolean removeMessage(String id) {
        Iterator<Map<String, Object>> it = messages.iterator();
        while (it.hasNext()) {
            if (id.equals(Json.str(it.next(), "id"))) {
                it.remove();
                markDirty();
                return true;
            }
        }
        return false;
    }

    synchronized Map<String, Object> findMessage(String id) {
        for (Map<String, Object> m : messages) if (id.equals(Json.str(m, "id"))) return m;
        return null;
    }

    synchronized void clearMessages() {
        messages.clear();
        markDirty();
    }

    synchronized List<Map<String, Object>> messagesFor(String deviceId, boolean host, int limit) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (int i = messages.size() - 1; i >= 0 && out.size() < limit; i--) {
            Map<String, Object> m = messages.get(i);
            if (canSee(m, deviceId, host)) out.add(0, m);
        }
        return out;
    }

    static boolean canSee(Map<String, Object> m, String deviceId, boolean host) {
        String to = Json.str(m, "to");
        // Private messages are visible only to the two devices involved, the host included.
        if (to == null || to.isEmpty()) return true;
        Object from = m.get("from");
        String fromId = from instanceof Map ? Json.str(castMap(from), "id") : null;
        return to.equals(deviceId) || (fromId != null && fromId.equals(deviceId));
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> castMap(Object o) {
        return (Map<String, Object>) o;
    }
}
