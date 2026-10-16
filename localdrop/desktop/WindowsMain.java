import com.ajay.localdrop.server.LocalDropServer;

import java.awt.AWTException;
import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Desktop;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.GraphicsEnvironment;
import java.awt.Image;
import java.awt.MenuItem;
import java.awt.PopupMenu;
import java.awt.RenderingHints;
import java.awt.SystemTray;
import java.awt.Toolkit;
import java.awt.TrayIcon;
import java.awt.datatransfer.StringSelection;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.awt.image.BufferedImage;
import java.io.File;
import java.net.URI;
import java.util.List;
import java.util.Map;
import javax.swing.BorderFactory;
import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JTextField;
import javax.swing.SwingUtilities;
import javax.swing.UIManager;

/**
 * LocalDrop for Windows (and any computer with a screen). Starts the server, opens LocalDrop in the browser and
 * shows the addresses and PIN in a small window with a tray icon. Without a screen it behaves like DesktopMain.
 */
public final class WindowsMain {
    private static LocalDropServer server;
    private static int port;
    private static JFrame frame;

    public static void main(String[] args) throws Exception {
        File appDir = appDir();
        File home = new File(System.getProperty("user.home", "."));
        File root = new File(home, "LocalDrop");
        File data = new File(home, ".localdrop");
        File web = new File(appDir, "web");
        int want = 8080;
        for (int i = 0; i < args.length; i++) {
            if (args[i].equals("--port") && i + 1 < args.length) want = Integer.parseInt(args[++i]);
            else if (args[i].equals("--root") && i + 1 < args.length) root = new File(args[++i]);
            else if (args[i].equals("--web") && i + 1 < args.length) web = new File(args[++i]);
        }
        //noinspection ResultOfMethodCallIgnored
        root.mkdirs();
        server = new LocalDropServer(new DesktopPlatform(data, root, web));
        port = server.start(want);
        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override public void run() { server.stop(); }
        });
        if (GraphicsEnvironment.isHeadless()) {
            System.out.println("LocalDrop is running at http://localhost:" + port + "/  PIN: " + (server.pinEnabled() ? server.pin() : "(off)"));
            Thread.currentThread().join();
            return;
        }
        try { UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName()); } catch (Exception ignored) { /* default look */ }
        final File shared = root;
        SwingUtilities.invokeLater(new Runnable() {
            @Override public void run() { buildWindow(shared); openBrowser(); }
        });
    }

    private static File appDir() {
        try {
            File f = new File(WindowsMain.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            return f.isFile() ? f.getParentFile() : f;
        } catch (Exception e) {
            return new File(".");
        }
    }

    private static void openBrowser() {
        try { Desktop.getDesktop().browse(new URI("http://localhost:" + port + "/")); } catch (Exception ignored) { /* the window shows the address */ }
    }

    private static JButton button(String text, Runnable r, boolean primary) {
        final Runnable run = r;
        JButton b = new JButton(text);
        b.setFont(b.getFont().deriveFont(Font.BOLD, 13f));
        if (primary) { b.setBackground(new Color(0x0a8f9c)); b.setForeground(Color.WHITE); b.setOpaque(true); b.setBorderPainted(false); }
        b.addActionListener(new java.awt.event.ActionListener() {
            @Override public void actionPerformed(java.awt.event.ActionEvent e) { run.run(); }
        });
        return b;
    }

    private static void buildWindow(final File shared) {
        frame = new JFrame("LocalDrop");
        frame.setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);
        JPanel p = new JPanel();
        p.setLayout(new BoxLayout(p, BoxLayout.Y_AXIS));
        p.setBorder(BorderFactory.createEmptyBorder(20, 24, 20, 24));

        JLabel title = new JLabel("LocalDrop is running");
        title.setFont(title.getFont().deriveFont(Font.BOLD, 22f));
        p.add(title);
        p.add(Box.createVerticalStrut(4));
        p.add(new JLabel("On another device, join the same Wi-Fi and open one of these addresses:"));
        p.add(Box.createVerticalStrut(10));

        List<Map<String, Object>> addrs = server.addresses();
        if (addrs.isEmpty()) p.add(new JLabel("No network found. Connect this computer to Wi-Fi or a cable."));
        for (Map<String, Object> a : addrs) {
            final String url = String.valueOf(a.get("url"));
            JPanel row = new JPanel(new BorderLayout(8, 0));
            JTextField t = new JTextField(url.replace("http://", ""));
            t.setEditable(false);
            t.setFont(new Font(Font.MONOSPACED, Font.BOLD, 16));
            row.add(new JLabel(String.valueOf(a.get("label"))), BorderLayout.WEST);
            row.add(t, BorderLayout.CENTER);
            row.add(button("Copy", new Runnable() {
                @Override public void run() { Toolkit.getDefaultToolkit().getSystemClipboard().setContents(new StringSelection(url), null); }
            }, false), BorderLayout.EAST);
            row.setMaximumSize(new Dimension(Integer.MAX_VALUE, 36));
            p.add(row);
            p.add(Box.createVerticalStrut(6));
        }
        p.add(Box.createVerticalStrut(8));
        JLabel pin = new JLabel(server.pinEnabled() ? "PIN  " + server.pin() : "No PIN is set. Anyone on the network can join.");
        pin.setFont(new Font(Font.MONOSPACED, Font.BOLD, 22));
        p.add(pin);
        p.add(Box.createVerticalStrut(6));
        JLabel hint = new JLabel("<html>Open LocalDrop in your browser to see the QR code, share files, chat and make calls.<br>Shared folder: " + shared.getPath() + "</html>");
        hint.setForeground(Color.GRAY);
        p.add(hint);
        p.add(Box.createVerticalStrut(16));

        JPanel btns = new JPanel();
        btns.setLayout(new BoxLayout(btns, BoxLayout.X_AXIS));
        btns.add(button("Open LocalDrop", new Runnable() { @Override public void run() { openBrowser(); } }, true));
        btns.add(Box.createHorizontalStrut(8));
        btns.add(button("Open shared folder", new Runnable() {
            @Override public void run() { try { Desktop.getDesktop().open(shared); } catch (Exception ignored) { /* no file manager */ } }
        }, false));
        btns.add(Box.createHorizontalGlue());
        btns.add(button("Quit", new Runnable() { @Override public void run() { quit(); } }, false));
        p.add(btns);

        for (java.awt.Component c : p.getComponents()) if (c instanceof javax.swing.JComponent) ((javax.swing.JComponent) c).setAlignmentX(java.awt.Component.LEFT_ALIGNMENT);
        frame.setContentPane(p);
        frame.setMinimumSize(new Dimension(560, 340));
        frame.pack();
        frame.setLocationRelativeTo(null);
        frame.setIconImage(icon(64));
        final boolean tray = addTray();
        frame.addWindowListener(new WindowAdapter() {
            @Override public void windowClosing(WindowEvent e) {
                if (tray) frame.setVisible(false); else quit();
            }
        });
        frame.setVisible(true);
    }

    private static boolean addTray() {
        if (!SystemTray.isSupported()) return false;
        try {
            PopupMenu menu = new PopupMenu();
            MenuItem open = new MenuItem("Open LocalDrop");
            open.addActionListener(new java.awt.event.ActionListener() { @Override public void actionPerformed(java.awt.event.ActionEvent e) { openBrowser(); } });
            MenuItem show = new MenuItem("Show window");
            show.addActionListener(new java.awt.event.ActionListener() { @Override public void actionPerformed(java.awt.event.ActionEvent e) { frame.setVisible(true); frame.toFront(); } });
            MenuItem quit = new MenuItem("Quit");
            quit.addActionListener(new java.awt.event.ActionListener() { @Override public void actionPerformed(java.awt.event.ActionEvent e) { quit(); } });
            menu.add(open); menu.add(show); menu.addSeparator(); menu.add(quit);
            TrayIcon ti = new TrayIcon(icon(32), "LocalDrop is running", menu);
            ti.setImageAutoSize(true);
            ti.addActionListener(new java.awt.event.ActionListener() { @Override public void actionPerformed(java.awt.event.ActionEvent e) { frame.setVisible(true); frame.toFront(); } });
            SystemTray.getSystemTray().add(ti);
            return true;
        } catch (AWTException e) {
            return false;
        }
    }

    private static void quit() {
        int r = JOptionPane.showConfirmDialog(frame, "Stop sharing and quit LocalDrop?", "LocalDrop", JOptionPane.YES_NO_OPTION);
        if (r == JOptionPane.YES_OPTION) { server.stop(); System.exit(0); }
    }

    private static Image icon(int s) {
        BufferedImage im = new BufferedImage(s, s, BufferedImage.TYPE_INT_ARGB);
        java.awt.Graphics2D g = im.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setColor(new Color(0x0a8f9c));
        g.fillOval(0, 0, s, s);
        g.setColor(Color.WHITE);
        g.setStroke(new java.awt.BasicStroke(s / 10f));
        g.drawOval(s / 4, s / 4, s / 2, s / 2);
        g.fillOval(s * 2 / 5, s * 2 / 5, s / 5, s / 5);
        g.dispose();
        return im;
    }
}
