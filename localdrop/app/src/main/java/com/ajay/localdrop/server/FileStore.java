package com.ajay.localdrop.server;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.zip.Deflater;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import com.ajay.localdrop.server.Http.HttpError;

/** Everything that touches the shared folder: safe paths, listing, edits, trash and zip. */
final class FileStore {
    static final String HIDDEN = ".localdrop";
    static final String PART = ".ldpart";

    private final Platform platform;
    private volatile File root;

    FileStore(Platform platform) {
        this.platform = platform;
    }

    synchronized void setRoot(File dir) throws IOException {
        if (!dir.exists() && !dir.mkdirs()) throw new IOException("Could not create " + dir);
        if (!dir.isDirectory()) throw new IOException("Not a folder: " + dir);
        root = dir.getCanonicalFile();
    }

    File root() {
        return root;
    }

    String rootLabel() {
        File r = root;
        String n = r == null ? "" : r.getName();
        return n.isEmpty() ? "Storage" : n;
    }

    // ---------------------------------------------------------------- paths

    File resolve(String rel) {
        File r = root;
        if (r == null) throw new HttpError(503, "No shared folder yet.");
        if (rel == null) rel = "";
        if (rel.indexOf('\0') >= 0) throw new HttpError(400, "Bad path");
        File f = r;
        for (String seg : rel.replace('\\', '/').split("/")) {
            if (seg.isEmpty() || seg.equals(".")) continue;
            if (seg.equals("..")) throw new HttpError(400, "Bad path");
            if (seg.startsWith(HIDDEN)) throw new HttpError(403, "That folder is not available.");
            f = new File(f, seg);
        }
        try {
            String c = f.getCanonicalPath();
            String rc = r.getPath();
            String prefix = rc.endsWith(File.separator) ? rc : rc + File.separator;
            if (!c.equals(rc) && !c.startsWith(prefix)) throw new HttpError(403, "That is outside the shared folder.");
        } catch (IOException e) {
            throw new HttpError(400, "Bad path");
        }
        return f;
    }

    String relOf(File f) {
        String root = this.root.getPath();
        String p = f.getPath();
        if (p.length() <= root.length()) return "";
        String r = p.substring(root.length()).replace(File.separatorChar, '/');
        return r.startsWith("/") ? r.substring(1) : r;
    }

    static String cleanName(String raw) {
        if (raw == null) throw new HttpError(400, "A name is required.");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < raw.length(); i++) {
            char c = raw.charAt(i);
            if (c < 0x20 || c == 0x7f) continue;
            sb.append(c);
        }
        String s = sb.toString().trim();
        if (s.isEmpty() || s.equals(".") || s.equals("..")) throw new HttpError(400, "Choose a different name.");
        if (s.indexOf('/') >= 0 || s.indexOf('\\') >= 0) throw new HttpError(400, "Names cannot contain / or \\.");
        if (s.getBytes(StandardCharsets.UTF_8).length > 240) throw new HttpError(400, "That name is too long.");
        if (s.startsWith(HIDDEN) || s.endsWith(PART)) throw new HttpError(400, "Choose a different name.");
        return s;
    }

    static String uniqueName(File dir, String name) {
        if (!new File(dir, name).exists()) return name;
        int dot = name.lastIndexOf('.');
        String base = dot > 0 ? name.substring(0, dot) : name;
        String ext = dot > 0 ? name.substring(dot) : "";
        for (int i = 1; i < 10000; i++) {
            String c = base + " (" + i + ")" + ext;
            if (!new File(dir, c).exists()) return c;
        }
        return base + " (" + System.currentTimeMillis() + ")" + ext;
    }

    // ---------------------------------------------------------------- listing

    Map<String, Object> entry(File f) {
        Map<String, Object> m = new LinkedHashMap<>();
        boolean dir = f.isDirectory();
        m.put("name", f.getName());
        m.put("path", relOf(f));
        m.put("dir", dir);
        m.put("size", dir ? 0 : f.length());
        m.put("mtime", f.lastModified());
        if (!dir) {
            m.put("mime", Mime.of(f.getName()));
            m.put("kind", Mime.kind(f.getName()));
        }
        return m;
    }

    private static boolean hiddenName(String n, boolean showHidden) {
        if (n.startsWith(HIDDEN) || n.endsWith(PART)) return true;
        return !showHidden && n.startsWith(".");
    }

    List<Map<String, Object>> list(File dir, boolean showHidden) {
        File[] fs = dir.listFiles();
        if (fs == null) throw new HttpError(403, "This folder can't be opened.");
        List<Map<String, Object>> out = new ArrayList<>(fs.length);
        for (File f : fs) {
            if (hiddenName(f.getName(), showHidden)) continue;
            out.add(entry(f));
            if (out.size() >= 6000) break;
        }
        return out;
    }

    List<Map<String, Object>> search(File from, String query, boolean showHidden) {
        String q = query.toLowerCase();
        List<Map<String, Object>> out = new ArrayList<>();
        ArrayDeque<File> queue = new ArrayDeque<>();
        queue.add(from);
        long deadline = System.currentTimeMillis() + 4000;
        int scanned = 0;
        while (!queue.isEmpty() && out.size() < 300 && scanned < 60000 && System.currentTimeMillis() < deadline) {
            File d = queue.poll();
            File[] fs = d.listFiles();
            if (fs == null) continue;
            for (File f : fs) {
                scanned++;
                String n = f.getName();
                if (hiddenName(n, showHidden)) continue;
                if (n.toLowerCase().contains(q)) {
                    out.add(entry(f));
                    if (out.size() >= 300) break;
                }
                if (f.isDirectory() && !Files.isSymbolicLink(f.toPath())) queue.add(f);
            }
        }
        return out;
    }

    // ---------------------------------------------------------------- edits

    File mkdir(File parent, String rawName) {
        String name = cleanName(rawName);
        File d = new File(parent, name);
        if (d.exists()) throw new HttpError(409, "\"" + name + "\" already exists here.");
        if (!d.mkdir()) throw new HttpError(500, "Could not create the folder.");
        return d;
    }

    File rename(File f, String rawName) {
        String name = cleanName(rawName);
        if (!f.exists()) throw new HttpError(404, "That item no longer exists.");
        File t = new File(f.getParentFile(), name);
        if (t.exists() && !t.getName().equalsIgnoreCase(f.getName())) {
            throw new HttpError(409, "\"" + name + "\" already exists here.");
        }
        if (t.equals(f)) return f;
        if (!f.renameTo(t)) throw new HttpError(500, "Could not rename that item.");
        return t;
    }

    File moveOrCopy(File src, File destDir, boolean copy) throws IOException {
        if (!src.exists()) throw new HttpError(404, "\"" + src.getName() + "\" no longer exists.");
        if (!destDir.isDirectory()) throw new HttpError(400, "Choose a folder to move into.");
        File parent = src.getParentFile();
        if (!copy && parent != null && parent.getCanonicalFile().equals(destDir.getCanonicalFile())) return src;
        if (src.isDirectory()) {
            String s = src.getCanonicalPath() + File.separator;
            String d = destDir.getCanonicalPath() + File.separator;
            if (d.startsWith(s)) throw new HttpError(400, "A folder can't be moved into itself.");
        }
        File target = new File(destDir, uniqueName(destDir, src.getName()));
        if (copy) {
            copyTree(src, target);
        } else {
            moveRaw(src, target);
        }
        return target;
    }

    private void moveRaw(File src, File dst) throws IOException {
        try {
            Files.move(src.toPath(), dst.toPath(), StandardCopyOption.ATOMIC_MOVE);
            return;
        } catch (AtomicMoveNotSupportedException ignored) {
            // fall through
        } catch (IOException ignored) {
            // fall through
        }
        if (src.renameTo(dst)) return;
        copyTree(src, dst);
        deleteTree(src);
    }

    private void copyTree(File src, File dst) throws IOException {
        if (Files.isSymbolicLink(src.toPath())) return;
        if (src.isDirectory()) {
            if (!dst.mkdirs() && !dst.isDirectory()) throw new IOException("Could not create " + dst);
            File[] kids = src.listFiles();
            if (kids != null) {
                for (File k : kids) {
                    if (k.getName().startsWith(HIDDEN)) continue;
                    copyTree(k, new File(dst, k.getName()));
                }
            }
            //noinspection ResultOfMethodCallIgnored
            dst.setLastModified(src.lastModified());
        } else {
            try (InputStream in = new FileInputStream(src); OutputStream out = new FileOutputStream(dst)) {
                byte[] buf = new byte[1024 * 1024];
                int n;
                while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            }
            //noinspection ResultOfMethodCallIgnored
            dst.setLastModified(src.lastModified());
        }
    }

    static void deleteTree(File f) {
        try {
            if (f.isDirectory() && !Files.isSymbolicLink(f.toPath())) {
                File[] kids = f.listFiles();
                if (kids != null) for (File k : kids) deleteTree(k);
            }
        } catch (RuntimeException ignored) { }
        //noinspection ResultOfMethodCallIgnored
        f.delete();
    }

    // ---------------------------------------------------------------- trash

    private File trashDir() {
        return new File(root, HIDDEN + File.separator + "trash");
    }

    private File trashIndex() {
        return new File(root, HIDDEN + File.separator + "trash.json");
    }

    private synchronized List<Map<String, Object>> readTrash() {
        List<Map<String, Object>> out = new ArrayList<>();
        File idx = trashIndex();
        if (!idx.exists()) return out;
        try {
            Object o = Json.parse(new String(Files.readAllBytes(idx.toPath()), StandardCharsets.UTF_8));
            if (o instanceof List) {
                for (Object x : (List<?>) o) {
                    if (x instanceof Map) out.add(Store.castMap(x));
                }
            }
        } catch (Exception e) {
            platform.log("Trash index unreadable: " + e);
        }
        return out;
    }

    private synchronized void writeTrash(List<Map<String, Object>> list) throws IOException {
        File idx = trashIndex();
        //noinspection ResultOfMethodCallIgnored
        idx.getParentFile().mkdirs();
        Files.write(idx.toPath(), Json.stringify(list).getBytes(StandardCharsets.UTF_8));
    }

    synchronized void moveToTrash(File f) throws IOException {
        if (!f.exists()) throw new HttpError(404, "\"" + f.getName() + "\" no longer exists.");
        String id = Store.randomToken(6);
        File holder = new File(trashDir(), id);
        if (!holder.mkdirs()) throw new IOException("Could not create trash folder");
        File dest = new File(holder, f.getName());
        boolean dir = f.isDirectory();
        long size = dir ? 0 : f.length();
        String orig = relOf(f);
        moveRaw(f, dest);
        List<Map<String, Object>> list = readTrash();
        list.add(Json.obj("id", id, "name", f.getName(), "orig", orig, "dir", dir, "size", size,
                "deleted", System.currentTimeMillis()));
        writeTrash(list);
    }

    synchronized List<Map<String, Object>> trashList() {
        List<Map<String, Object>> list = readTrash();
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> m : list) {
            File h = new File(trashDir(), Json.str(m, "id"));
            if (h.exists()) out.add(m);
        }
        java.util.Collections.reverse(out);
        return out;
    }

    synchronized String restore(String id) throws IOException {
        List<Map<String, Object>> list = readTrash();
        Map<String, Object> rec = null;
        for (Map<String, Object> m : list) if (id.equals(Json.str(m, "id"))) rec = m;
        if (rec == null) throw new HttpError(404, "That item is no longer in the trash.");
        File holder = new File(trashDir(), id);
        File src = new File(holder, Json.str(rec, "name"));
        if (!src.exists()) {
            list.remove(rec);
            writeTrash(list);
            throw new HttpError(404, "That item is no longer in the trash.");
        }
        String orig = Json.str(rec, "orig");
        String parentRel = orig.contains("/") ? orig.substring(0, orig.lastIndexOf('/')) : "";
        File parent = resolve(parentRel);
        if (!parent.exists() && !parent.mkdirs()) parent = root;
        File target = new File(parent, uniqueName(parent, src.getName()));
        moveRaw(src, target);
        deleteTree(holder);
        list.remove(rec);
        writeTrash(list);
        return relOf(target);
    }

    synchronized void emptyTrash() throws IOException {
        deleteTree(trashDir());
        writeTrash(new ArrayList<Map<String, Object>>());
    }

    synchronized void purgeTrash(int days) {
        try {
            if (root == null) return;
            long cutoff = System.currentTimeMillis() - days * 86400000L;
            List<Map<String, Object>> list = readTrash();
            boolean changed = false;
            Iterator<Map<String, Object>> it = list.iterator();
            while (it.hasNext()) {
                Map<String, Object> m = it.next();
                if (Json.num(m, "deleted", 0) < cutoff) {
                    deleteTree(new File(trashDir(), Json.str(m, "id")));
                    it.remove();
                    changed = true;
                }
            }
            if (changed) writeTrash(list);
        } catch (Exception e) {
            platform.log("Trash cleanup failed: " + e);
        }
    }

    // ---------------------------------------------------------------- text

    String readText(File f) throws IOException {
        if (!f.isFile()) throw new HttpError(404, "File not found.");
        if (f.length() > 1024 * 1024) throw new HttpError(413, "This file is too large to open as text.");
        byte[] b = Files.readAllBytes(f.toPath());
        for (int i = 0; i < Math.min(b.length, 4096); i++) {
            if (b[i] == 0) throw new HttpError(415, "This looks like a binary file.");
        }
        return new String(b, StandardCharsets.UTF_8);
    }

    void writeText(File f, String content) throws IOException {
        byte[] b = content.getBytes(StandardCharsets.UTF_8);
        if (b.length > 2 * 1024 * 1024) throw new HttpError(413, "That is too large to save as text.");
        File tmp = new File(f.getParentFile(), ".ld-" + Store.randomToken(4) + PART);
        try {
            Files.write(tmp.toPath(), b);
            try {
                Files.move(tmp.toPath(), f.toPath(), StandardCopyOption.REPLACE_EXISTING);
            } catch (IOException e) {
                Files.write(f.toPath(), b);
            }
        } finally {
            //noinspection ResultOfMethodCallIgnored
            tmp.delete();
        }
    }

    // ---------------------------------------------------------------- zip

    interface Counter {
        void add(long n);
    }

    void zip(List<File> items, OutputStream out, Counter counter) throws IOException {
        ZipOutputStream z = new ZipOutputStream(out);
        z.setLevel(Deflater.BEST_SPEED);
        Set<String> used = new HashSet<>();
        int[] count = {0};
        for (File f : items) addTree(z, f, f.getName(), used, count, counter);
        z.finish();
    }

    private void addTree(ZipOutputStream z, File f, String name, Set<String> used, int[] count, Counter counter)
            throws IOException {
        if (count[0]++ > 200000) throw new IOException("Too many files to zip");
        if (Files.isSymbolicLink(f.toPath())) return;
        if (f.isDirectory()) {
            String dn = uniqueEntry(used, name + "/");
            ZipEntry de = new ZipEntry(dn);
            de.setTime(f.lastModified());
            z.putNextEntry(de);
            z.closeEntry();
            File[] kids = f.listFiles();
            if (kids == null) return;
            for (File k : kids) {
                String n = k.getName();
                if (n.startsWith(HIDDEN) || n.endsWith(PART)) continue;
                addTree(z, k, dn + n, used, count, counter);
            }
            return;
        }
        if (!f.isFile()) return;
        InputStream in;
        try {
            in = new FileInputStream(f);
        } catch (IOException e) {
            return;
        }
        try {
            ZipEntry e = new ZipEntry(uniqueEntry(used, name));
            e.setTime(f.lastModified());
            z.setLevel(Mime.isCompressed(f.getName()) ? Deflater.NO_COMPRESSION : Deflater.BEST_SPEED);
            z.putNextEntry(e);
            byte[] buf = new byte[1024 * 1024];
            int n;
            while ((n = in.read(buf)) > 0) {
                z.write(buf, 0, n);
                if (counter != null) counter.add(n);
            }
            z.closeEntry();
        } finally {
            try { in.close(); } catch (IOException ignored) { }
        }
    }

    private static String uniqueEntry(Set<String> used, String name) {
        if (used.add(name)) return name;
        boolean dir = name.endsWith("/");
        String base = dir ? name.substring(0, name.length() - 1) : name;
        int slash = base.lastIndexOf('/');
        int dot = base.lastIndexOf('.');
        String stem = dot > slash + 1 ? base.substring(0, dot) : base;
        String ext = dot > slash + 1 ? base.substring(dot) : "";
        for (int i = 1; i < 100000; i++) {
            String c = stem + " (" + i + ")" + ext + (dir ? "/" : "");
            if (used.add(c)) return c;
        }
        return name;
    }

    // ---------------------------------------------------------------- storage

    Map<String, Object> storage() {
        File r = root;
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("total", r.getTotalSpace());
        m.put("free", r.getUsableSpace());
        m.put("name", rootLabel());
        return m;
    }
}
