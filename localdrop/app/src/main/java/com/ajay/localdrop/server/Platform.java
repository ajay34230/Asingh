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

    /** An installed app whose APK can be handed to another device. */
    final class AppEntry {
        public String pkg;
        public String label;
        public long size;
        /** True for apps delivered as several APK files (app bundles); only the base file can be shared. */
        public boolean split;
        public AppEntry(String pkg, String label, long size, boolean split) {
            this.pkg = pkg;
            this.label = label;
            this.size = size;
            this.split = split;
        }
    }

    /** Installed apps that may be shared. When everything is false, only this app is listed. Empty where unsupported. */
    List<AppEntry> installedApps(boolean everything);

    /** The APK file of an installed app, or null. */
    File apkFile(String pkg);

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

    /** Other LocalDrop phones nearby and which one hosts the shared room, or null when this platform doesn't look for them. */
    default java.util.Map<String, Object> room() { return null; }

    /** Extra {interfaceName, ipv4} pairs for platforms where listing network interfaces is restricted. */
    List<String[]> fallbackAddresses();

    /** Friendly name of this device, for example "Pixel 8". */
    String deviceName();

    /** "phone" or "desktop". */
    String deviceKind();

    String version();

    void log(String message);
}
