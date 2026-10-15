import com.ajay.localdrop.server.LocalDropServer;

import java.io.File;
import java.util.Map;

/**
 * Runs LocalDrop on a computer.
 *   java -cp out DesktopMain --port 8080 --root ~/LocalDrop --web app/src/main/assets/web
 */
public final class DesktopMain {
    public static void main(String[] args) throws Exception {
        int port = 8080;
        File home = new File(System.getProperty("user.home", "."));
        File root = new File(home, "LocalDrop");
        File data = new File(home, ".localdrop");
        File web = new File("app/src/main/assets/web");
        String pin = null;
        boolean noPin = false;
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--port": port = Integer.parseInt(args[++i]); break;
                case "--root": root = new File(args[++i]); break;
                case "--data": data = new File(args[++i]); break;
                case "--web": web = new File(args[++i]); break;
                case "--pin": pin = args[++i]; break;
                case "--no-pin": noPin = true; break;
                default: System.err.println("Unknown option " + args[i]);
            }
        }
        final LocalDropServer server = new LocalDropServer(new DesktopPlatform(data, root, web));
        if (pin != null) server.setPin(pin);
        if (noPin) server.setPinEnabled(false);
        int actual = server.start(port);
        System.out.println("LocalDrop is running.");
        System.out.println("Sharing folder: " + server.rootPath());
        System.out.println("PIN: " + (server.pinEnabled() ? server.pin() : "(off)"));
        System.out.println("Open on this computer: http://localhost:" + actual + "/");
        for (Map<String, Object> a : server.addresses()) {
            System.out.println("Open from other devices (" + a.get("label") + "): " + a.get("url") + "/?k=" + server.pin());
        }
        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override public void run() { server.stop(); }
        });
        Thread.currentThread().join();
    }
}
