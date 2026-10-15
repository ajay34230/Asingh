package com.ajay.localdrop.server;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;

/**
 * Everything the server needs from the device it runs on. The Android app and the desktop runner each provide one,
 * which keeps the server itself free of any Android classes so it can be tested on a normal computer.
 */
public interface Platform {

    /** A folder the host can choose to share. */
    final class RootOption {
        public String id;
        public String label;
        public String path;
        public String note;
        /** False when the folder cannot be used yet, for example because storage access has not been granted. */
        public boolean available;
        public RootOption(String id, String label, String path, String note, boolean available) {
            this.id = id;
            this.label = label;
            this.path = path;
            this.note = note;
            this.available = available;
        }
    }

    /** Private folder for settings, tokens and message history. */
    File dataDir();

    /** Folder shared the first time the app runs. */
    File defaultRoot();

    List<RootOption> rootOptions();

    /** Whether the host may share this folder on this platform. */
    boolean isRootAllowed(File dir);

    /** Opens a bundled web file such as "index.html", or returns null when it does not exist. */
    InputStream openAsset(String path) throws IOException;

    /** JPEG thumbnail bytes for an image or video, or null when this platform cannot make one. */
    byte[] thumbnail(File file, int width);

    /** Extra {interfaceName, ipv4} pairs for platforms where listing network interfaces is restricted. */
    List<String[]> fallbackAddresses();

    /** Friendly name of this device, for example "Pixel 8". */
    String deviceName();

    /** "phone" or "desktop". */
    String deviceKind();

    String version();

    void log(String message);
}
