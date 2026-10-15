package com.ajay.localdrop.server;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/** File type helpers: MIME type, a coarse "kind" used for icons, and inline-safety. */
public final class Mime {
    private Mime() {}

    private static final Map<String, String> TYPES = new HashMap<>();
    private static final Map<String, String> KINDS = new HashMap<>();

    private static void t(String mime, String kind, String... exts) {
        for (String e : exts) {
            TYPES.put(e, mime);
            KINDS.put(e, kind);
        }
    }

    static {
        t("image/jpeg", "image", "jpg", "jpeg", "jpe");
        t("image/png", "image", "png");
        t("image/gif", "image", "gif");
        t("image/webp", "image", "webp");
        t("image/avif", "image", "avif");
        t("image/bmp", "image", "bmp");
        t("image/heic", "image", "heic", "heif");
        t("image/svg+xml", "image", "svg");
        t("image/x-icon", "image", "ico");
        t("video/mp4", "video", "mp4", "m4v");
        t("video/webm", "video", "webm");
        t("video/quicktime", "video", "mov");
        t("video/x-matroska", "video", "mkv");
        t("video/x-msvideo", "video", "avi");
        t("video/3gpp", "video", "3gp");
        t("video/mpeg", "video", "mpg", "mpeg");
        t("audio/mpeg", "audio", "mp3");
        t("audio/mp4", "audio", "m4a", "aac");
        t("audio/ogg", "audio", "ogg", "oga", "opus");
        t("audio/wav", "audio", "wav");
        t("audio/flac", "audio", "flac");
        t("audio/amr", "audio", "amr");
        t("application/pdf", "pdf", "pdf");
        t("application/zip", "archive", "zip");
        t("application/vnd.rar", "archive", "rar");
        t("application/x-7z-compressed", "archive", "7z");
        t("application/gzip", "archive", "gz", "tgz");
        t("application/x-tar", "archive", "tar");
        t("application/x-bzip2", "archive", "bz2");
        t("application/vnd.android.package-archive", "apk", "apk");
        t("application/msword", "doc", "doc");
        t("application/vnd.openxmlformats-officedocument.wordprocessingml.document", "doc", "docx");
        t("application/vnd.oasis.opendocument.text", "doc", "odt");
        t("application/rtf", "doc", "rtf");
        t("application/vnd.ms-excel", "sheet", "xls");
        t("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "sheet", "xlsx");
        t("application/vnd.oasis.opendocument.spreadsheet", "sheet", "ods");
        t("text/csv", "sheet", "csv", "tsv");
        t("application/vnd.ms-powerpoint", "slides", "ppt");
        t("application/vnd.openxmlformats-officedocument.presentationml.presentation", "slides", "pptx");
        t("application/vnd.oasis.opendocument.presentation", "slides", "odp");
        t("text/plain", "text", "txt", "log", "md", "markdown", "ini", "cfg", "conf", "nfo");
        t("text/html", "code", "html", "htm");
        t("text/css", "code", "css");
        t("text/javascript", "code", "js", "mjs");
        t("application/json", "code", "json");
        t("application/xml", "code", "xml");
        t("text/yaml", "code", "yml", "yaml", "toml");
        t("text/x-java", "code", "java", "kt", "py", "c", "h", "cpp", "hpp", "cs", "go", "rs", "rb", "php", "sh", "bat",
                "ps1", "ts", "tsx", "jsx", "sql", "gradle", "swift", "lua", "dart", "vue");
        t("application/epub+zip", "doc", "epub");
        t("font/ttf", "other", "ttf");
        t("font/otf", "other", "otf");
        t("font/woff2", "other", "woff2");
        t("font/woff", "other", "woff");
    }

    public static String ext(String name) {
        int i = name.lastIndexOf('.');
        if (i <= 0 || i == name.length() - 1) return "";
        return name.substring(i + 1).toLowerCase(Locale.ROOT);
    }

    public static String of(String name) {
        String m = TYPES.get(ext(name));
        return m == null ? "application/octet-stream" : m;
    }

    public static String kind(String name) {
        String k = KINDS.get(ext(name));
        return k == null ? "file" : k;
    }

    /**
     * Whether a browser may render this type inline on our origin. HTML, SVG and XML can run script, so a file that
     * somebody uploaded must never be rendered inside the app's origin; those are always sent as downloads.
     */
    public static boolean inlineSafe(String mime) {
        if (mime.startsWith("image/") && !mime.equals("image/svg+xml")) return true;
        if (mime.startsWith("video/") || mime.startsWith("audio/")) return true;
        return mime.equals("application/pdf") || mime.equals("text/plain") || mime.equals("text/csv");
    }

    public static boolean isCompressed(String name) {
        switch (ext(name)) {
            case "jpg": case "jpeg": case "png": case "gif": case "webp": case "avif": case "heic": case "heif":
            case "mp4": case "m4v": case "mov": case "mkv": case "webm": case "avi": case "3gp":
            case "mp3": case "m4a": case "aac": case "ogg": case "opus": case "flac":
            case "zip": case "rar": case "7z": case "gz": case "tgz": case "bz2": case "apk":
            case "docx": case "xlsx": case "pptx": case "epub": case "pdf":
                return true;
            default:
                return false;
        }
    }
}
