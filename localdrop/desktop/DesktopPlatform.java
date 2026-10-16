import com.ajay.localdrop.server.Platform;

import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.util.ArrayList;
import java.util.List;
import javax.imageio.ImageIO;

/** Runs LocalDrop on a normal computer. Handy for trying the app and for automated tests. */
public final class DesktopPlatform implements Platform {
    private final File data;
    private final File root;
    private final File web;

    public DesktopPlatform(File data, File root, File web) {
        this.data = data;
        this.root = root;
        this.web = web;
    }

    @Override public File dataDir() { return data; }

    @Override public File defaultRoot() { return root; }

    @Override public List<RootOption> rootOptions() {
        List<RootOption> l = new ArrayList<>();
        File home = new File(System.getProperty("user.home", "."));
        l.add(new RootOption("app", "LocalDrop folder", new File(home, "LocalDrop").getPath(),
                "A folder just for sharing", true));
        l.add(new RootOption("downloads", "Downloads", new File(home, "Downloads").getPath(), "Your Downloads folder",
                new File(home, "Downloads").isDirectory()));
        l.add(new RootOption("home", "Home folder", home.getPath(), "Everything in your home folder", true));
        return l;
    }

    @Override public boolean isRootAllowed(File dir) { return dir.isDirectory() || dir.getParentFile() != null; }

    @Override public InputStream openAsset(String path) throws IOException {
        File f = new File(web, path);
        if (!f.isFile()) return null;
        return new FileInputStream(f);
    }

    @Override public byte[] thumbnail(File file, int width) {
        try {
            BufferedImage src = ImageIO.read(file);
            if (src == null) return null;
            double s = Math.min(1.0, (double) width / Math.max(src.getWidth(), src.getHeight()));
            int w = Math.max(1, (int) Math.round(src.getWidth() * s));
            int h = Math.max(1, (int) Math.round(src.getHeight() * s));
            BufferedImage out = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = out.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
            g.drawImage(src, 0, 0, w, h, null);
            g.dispose();
            ByteArrayOutputStream bo = new ByteArrayOutputStream();
            ImageIO.write(out, "jpg", bo);
            return bo.toByteArray();
        } catch (Throwable t) {
            return null;
        }
    }

    /** For tests: -Dld.testapk=/path/app.apk pretends this computer has one installable app. */
    @Override public List<AppEntry> installedApps(boolean everything) {
        List<AppEntry> l = new ArrayList<>();
        String t = System.getProperty("ld.testapk");
        if (t != null && new File(t).isFile()) l.add(new AppEntry("test.app", "Test App", new File(t).length(), false));
        return l;
    }

    @Override public File apkFile(String pkg) {
        String t = System.getProperty("ld.testapk");
        return t != null && pkg.equals("test.app") ? new File(t) : null;
    }

    /** The Windows app joins the shared room as the hub: its id sorts first, so phones on the network move to it. */
    @Override public java.util.Map<String, Object> room() {
        if (System.getProperty("ld.room") == null) return null;
        java.util.Map<String, Object> m = new java.util.LinkedHashMap<>();
        m.put("on", true);
        m.put("self", "0000windows");
        m.put("seen", new ArrayList<String>());
        java.util.Map<String, Object> l = new java.util.LinkedHashMap<>();
        l.put("id", "0000windows");
        l.put("self", true);
        l.put("name", deviceName());
        m.put("leader", l);
        return m;
    }

    @Override public List<String[]> fallbackAddresses() { return new ArrayList<>(); }

    @Override public String deviceName() {
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            return "This computer";
        }
    }

    @Override public String deviceKind() { return "desktop"; }

    @Override public String version() { return "1.0.0"; }

    @Override public void log(String message) { System.out.println("[LocalDrop] " + message); }
}
