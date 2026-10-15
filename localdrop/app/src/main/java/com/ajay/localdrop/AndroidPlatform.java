package com.ajay.localdrop;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.media.MediaMetadataRetriever;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;
import android.util.Log;

import com.ajay.localdrop.server.Mime;
import com.ajay.localdrop.server.Platform;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;

/** Connects the server to Android: storage locations, bundled web files, thumbnails and the device name. */
final class AndroidPlatform implements Platform {
    private final Context ctx;

    AndroidPlatform(Context context) {
        this.ctx = context.getApplicationContext();
    }

    // ---------------------------------------------------------------- storage

    boolean hasStorageAccess() {
        if (Build.VERSION.SDK_INT >= 30) return Environment.isExternalStorageManager();
        return ctx.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
    }

    private File appFolder() {
        File ext = ctx.getExternalFilesDir(null);
        File base = ext != null ? ext : ctx.getFilesDir();
        return new File(base, "LocalDrop");
    }

    @Override public File dataDir() {
        return new File(ctx.getFilesDir(), "ld");
    }

    @Override public File defaultRoot() {
        return appFolder();
    }

    @Override public List<RootOption> rootOptions() {
        boolean access = hasStorageAccess();
        File ext = Environment.getExternalStorageDirectory();
        List<RootOption> l = new ArrayList<>();
        l.add(new RootOption("localdrop", "LocalDrop folder", new File(ext, "LocalDrop").getPath(),
                "A folder of its own on your phone that any file app can see", access));
        l.add(new RootOption("downloads", "Downloads",
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).getPath(),
                "Everything in your Downloads folder", access));
        l.add(new RootOption("pictures", "Photos and videos",
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM).getPath(),
                "Your camera roll (DCIM)", access));
        l.add(new RootOption("storage", "Entire phone storage", ext.getPath(),
                "Every file on the phone, including Downloads, Photos and Documents", access));
        l.add(new RootOption("app", "App-only folder", appFolder().getPath(),
                "Private to LocalDrop. Needs no permission, but other apps can't see it", true));
        return l;
    }

    @Override public boolean isRootAllowed(File dir) {
        try {
            String c = dir.getCanonicalPath();
            File a = appFolder().getParentFile();
            if (a != null && c.startsWith(a.getCanonicalPath())) return true;
            String ext = Environment.getExternalStorageDirectory().getCanonicalPath();
            return c.startsWith(ext) && hasStorageAccess();
        } catch (IOException e) {
            return false;
        }
    }

    // ---------------------------------------------------------------- assets

    @Override public InputStream openAsset(String path) throws IOException {
        try {
            return ctx.getAssets().open("web/" + path);
        } catch (FileNotFoundException e) {
            return null;
        }
    }

    // ---------------------------------------------------------------- thumbnails

    @Override public byte[] thumbnail(File file, int width) {
        String kind = Mime.kind(file.getName());
        if (!kind.equals("image") && !kind.equals("video")) return null;
        if (file.getName().toLowerCase().endsWith(".svg")) return null;
        try {
            File cacheDir = new File(ctx.getCacheDir(), "thumbs");
            //noinspection ResultOfMethodCallIgnored
            cacheDir.mkdirs();
            File cached = new File(cacheDir, sha1(file.getPath() + "|" + file.lastModified() + "|" + file.length() + "|" + width) + ".jpg");
            if (cached.isFile()) return readAll(cached);
            Bitmap bmp = kind.equals("image") ? decodeImage(file, width) : decodeVideo(file, width);
            if (bmp == null) return null;
            ByteArrayOutputStream bo = new ByteArrayOutputStream();
            bmp.compress(Bitmap.CompressFormat.JPEG, 80, bo);
            bmp.recycle();
            byte[] out = bo.toByteArray();
            try (FileOutputStream fo = new FileOutputStream(cached)) {
                fo.write(out);
            } catch (IOException ignored) {
                // cache is optional
            }
            trimCache(cacheDir);
            return out;
        } catch (Throwable t) {
            return null;
        }
    }

    private static Bitmap decodeImage(File f, int target) throws IOException {
        BitmapFactory.Options o = new BitmapFactory.Options();
        o.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(f.getPath(), o);
        if (o.outWidth <= 0 || o.outHeight <= 0) return null;
        int sample = 1;
        while (Math.max(o.outWidth, o.outHeight) / (sample * 2) >= target) sample *= 2;
        o.inJustDecodeBounds = false;
        o.inSampleSize = sample;
        o.inPreferredConfig = Bitmap.Config.RGB_565;
        Bitmap b = BitmapFactory.decodeFile(f.getPath(), o);
        if (b == null) return null;
        int rotation = 0;
        try {
            ExifInterface ex = new ExifInterface(f.getPath());
            int ori = ex.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);
            if (ori == ExifInterface.ORIENTATION_ROTATE_90) rotation = 90;
            else if (ori == ExifInterface.ORIENTATION_ROTATE_180) rotation = 180;
            else if (ori == ExifInterface.ORIENTATION_ROTATE_270) rotation = 270;
        } catch (Throwable ignored) {
            // no EXIF data
        }
        return fit(b, target, rotation);
    }

    private static Bitmap decodeVideo(File f, int target) {
        MediaMetadataRetriever r = new MediaMetadataRetriever();
        try {
            r.setDataSource(f.getPath());
            Bitmap b = r.getFrameAtTime(1000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
            if (b == null) b = r.getFrameAtTime();
            if (b == null) return null;
            return fit(b, target, 0);
        } catch (Throwable t) {
            return null;
        } finally {
            try { r.release(); } catch (Throwable ignored) { }
        }
    }

    private static Bitmap fit(Bitmap b, int target, int rotation) {
        float scale = Math.min(1f, (float) target / Math.max(b.getWidth(), b.getHeight()));
        if (scale >= 1f && rotation == 0) return b;
        Matrix m = new Matrix();
        m.postScale(scale, scale);
        if (rotation != 0) m.postRotate(rotation);
        Bitmap out = Bitmap.createBitmap(b, 0, 0, b.getWidth(), b.getHeight(), m, true);
        if (out != b) b.recycle();
        return out;
    }

    private static void trimCache(File dir) {
        File[] fs = dir.listFiles();
        if (fs == null || fs.length < 1500) return;
        java.util.Arrays.sort(fs, new java.util.Comparator<File>() {
            @Override public int compare(File a, File b) {
                return Long.compare(a.lastModified(), b.lastModified());
            }
        });
        for (int i = 0; i < fs.length / 3; i++) {
            //noinspection ResultOfMethodCallIgnored
            fs[i].delete();
        }
    }

    private static byte[] readAll(File f) throws IOException {
        try (InputStream in = new FileInputStream(f)) {
            ByteArrayOutputStream bo = new ByteArrayOutputStream((int) f.length());
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) bo.write(buf, 0, n);
            return bo.toByteArray();
        }
    }

    private static String sha1(String s) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-1");
        byte[] d = md.digest(s.getBytes("UTF-8"));
        StringBuilder sb = new StringBuilder();
        for (byte x : d) sb.append(String.format("%02x", x & 0xff));
        return sb.toString();
    }

    // ---------------------------------------------------------------- device

    @Override public String deviceName() {
        try {
            String n = Settings.Global.getString(ctx.getContentResolver(), "device_name");
            if (n != null && !n.trim().isEmpty()) return n.trim();
        } catch (Throwable ignored) {
            // fall back to the model name
        }
        String model = Build.MODEL == null ? "Android" : Build.MODEL;
        String maker = Build.MANUFACTURER == null ? "" : Build.MANUFACTURER;
        if (!maker.isEmpty() && !model.toLowerCase().startsWith(maker.toLowerCase())) {
            return Character.toUpperCase(maker.charAt(0)) + maker.substring(1) + " " + model;
        }
        return model;
    }

    @Override public String deviceKind() {
        Configuration c = ctx.getResources().getConfiguration();
        return c.smallestScreenWidthDp >= 600 ? "tablet" : "phone";
    }

    @Override public String version() {
        try {
            return ctx.getPackageManager().getPackageInfo(ctx.getPackageName(), 0).versionName;
        } catch (Exception e) {
            return "1.0.0";
        }
    }

    @Override public void log(String message) {
        Log.i("LocalDrop", message);
    }
}
