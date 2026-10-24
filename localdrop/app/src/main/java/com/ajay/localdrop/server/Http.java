package com.ajay.localdrop.server;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.BindException;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Semaphore;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

/** A small HTTP/1.1 server: keep-alive, range-friendly streaming, chunked responses and event streams. */
public final class Http {

    public interface Handler {
        void handle(Request req, Response res) throws Exception;
    }

    public static final class HttpError extends RuntimeException {
        public final int status;
        public HttpError(int status, String message) {
            super(message);
            this.status = status;
        }
    }

    private final Handler handler;
    private final Platform log;
    private ServerSocket server;
    private ServerSocket tlsServer;
    private int tlsPort;
    private ExecutorService pool;
    private final Semaphore slots = new Semaphore(300);
    private volatile boolean running;
    private int port;

    public Http(Handler handler, Platform log) {
        this.handler = handler;
        this.log = log;
    }

    public int port() {
        return port;
    }

    /** Port of the HTTPS listener, or 0 when there is none. */
    public int tlsPort() {
        return tlsPort;
    }

    /** Starts listening on all interfaces. Tries the preferred port, then the next few, then any free port. */
    public synchronized int start(int preferred) throws IOException {
        if (running) return port;
        ServerSocket s = null;
        for (int i = 0; i < 25 && s == null; i++) {
            int p = preferred + i;
            if (p > 65535) break;
            s = tryBind(p);
        }
        if (s == null) s = tryBind(0);
        if (s == null) throw new BindException("No free port");
        server = s;
        port = s.getLocalPort();
        running = true;
        final AtomicInteger n = new AtomicInteger();
        pool = Executors.newCachedThreadPool(new ThreadFactory() {
            @Override public Thread newThread(Runnable r) {
                Thread t = new Thread(r, "ld-conn-" + n.incrementAndGet());
                t.setDaemon(true);
                return t;
            }
        });
        startAcceptor(server, "ld-accept");
        return port;
    }

    private void startAcceptor(final ServerSocket srv, String name) {
        Thread acceptor = new Thread(new Runnable() {
            @Override public void run() { acceptLoop(srv); }
        }, name);
        acceptor.setDaemon(true);
        acceptor.start();
    }

    /** Adds an HTTPS listener (browsers only allow the camera and microphone on secure pages). Returns the port, or 0. */
    public synchronized int startTls(int preferred, javax.net.ssl.SSLContext ctx) {
        if (!running || ctx == null) return 0;
        for (int i = 0; i < 25; i++) {
            int p = preferred + i;
            if (p > 65535 || p == port) continue;
            try {
                ServerSocket s = ctx.getServerSocketFactory().createServerSocket();
                s.setReuseAddress(true);
                s.bind(new InetSocketAddress(p), 128);
                tlsServer = s;
                tlsPort = s.getLocalPort();
                startAcceptor(s, "ld-accept-tls");
                return tlsPort;
            } catch (IOException e) {
                // try the next port
            }
        }
        return 0;
    }

    private static ServerSocket tryBind(int p) {
        try {
            ServerSocket s = new ServerSocket();
            s.setReuseAddress(true);
            s.setReceiveBufferSize(4 * 1024 * 1024);
            s.bind(new InetSocketAddress(p), 128);
            return s;
        } catch (IOException e) {
            return null;
        }
    }

    public synchronized void stop() {
        running = false;
        try { if (server != null) server.close(); } catch (IOException ignored) { }
        try { if (tlsServer != null) tlsServer.close(); } catch (IOException ignored) { }
        tlsServer = null;
        tlsPort = 0;
        if (pool != null) pool.shutdownNow();
        server = null;
    }

    public boolean isRunning() {
        return running;
    }

    private void acceptLoop(ServerSocket srv) {
        while (running) {
            try {
                final Socket c = srv.accept();
                if (!slots.tryAcquire()) {
                    try { c.close(); } catch (IOException ignored) { }
                    continue;
                }
                try {
                    pool.execute(new Runnable() {
                        @Override public void run() {
                            try { new Conn(c).run(); } finally { slots.release(); }
                        }
                    });
                } catch (RuntimeException rejected) {
                    slots.release();
                    try { c.close(); } catch (IOException ignored) { }
                }
            } catch (IOException e) {
                if (!running) break;
                try { Thread.sleep(50); } catch (InterruptedException ie) { break; }
            }
        }
    }

    // ---------------------------------------------------------------- connection

    private final class Conn {
        final Socket sock;

        Conn(Socket s) { sock = s; }

        void run() {
            try {
                sock.setTcpNoDelay(true);
                sock.setSendBufferSize(4 * 1024 * 1024);
                InetSocketAddress ra = (InetSocketAddress) sock.getRemoteSocketAddress();
                String ip = ra.getAddress().getHostAddress();
                int pct = ip.indexOf('%');
                if (pct > 0) ip = ip.substring(0, pct);
                if (ip.startsWith("::ffff:")) ip = ip.substring(7);
                boolean loop = ra.getAddress().isLoopbackAddress();
                InputStream in = new java.io.BufferedInputStream(sock.getInputStream(), 256 * 1024);
                OutputStream out = sock.getOutputStream();
                boolean first = true;
                while (running) {
                    sock.setSoTimeout(first ? 30000 : 20000);
                    Request req;
                    try {
                        req = readRequest(in, out, ip, loop);
                    } catch (HttpError he) {
                        Response r = new Response(null, out);
                        r.closeAfter = true;
                        try { r.error(he.status, he.getMessage()); } catch (IOException ignored) { }
                        break;
                    }
                    if (req == null) break;
                    first = false;
                    sock.setSoTimeout(60000);
                    Response res = new Response(req, out);
                    try {
                        handler.handle(req, res);
                    } catch (HttpError he) {
                        if (res.headSent) break;
                        res.error(he.status, he.getMessage());
                    } catch (IOException io) {
                        break;
                    } catch (Throwable t) {
                        log.log("Handler error on " + req.method + " " + req.path + ": " + t);
                        if (res.headSent) break;
                        res.error(500, "Something went wrong on the server.");
                    }
                    if (!res.finished) {
                        if (!res.headSent) res.error(500, "No response");
                        else res.end();
                    }
                    if (res.closeAfter || !req.keepAlive) break;
                    if (!req.drainBody()) break;
                }
            } catch (IOException ignored) {
                // client went away
            } catch (RuntimeException e) {
                log.log("Connection error: " + e);
            } finally {
                try { sock.close(); } catch (IOException ignored) { }
            }
        }
    }

    private static String readLine(InputStream in, int max) throws IOException {
        byte[] buf = new byte[256];
        int n = 0;
        int c;
        while ((c = in.read()) != -1) {
            if (c == '\n') {
                if (n > 0 && buf[n - 1] == '\r') n--;
                return new String(buf, 0, n, StandardCharsets.ISO_8859_1);
            }
            if (n >= max) throw new HttpError(431, "Header too large");
            if (n == buf.length) buf = java.util.Arrays.copyOf(buf, Math.min(max, buf.length * 2));
            buf[n++] = (byte) c;
        }
        return null;
    }

    private static Request readRequest(InputStream in, OutputStream out, String ip, boolean loop) throws IOException {
        String line;
        try {
            do {
                line = readLine(in, 16384);
                if (line == null) return null;
            } while (line.isEmpty());
        } catch (java.net.SocketTimeoutException e) {
            return null;
        }
        String[] parts = line.split(" ");
        if (parts.length < 3) throw new HttpError(400, "Bad request");
        String method = parts[0].toUpperCase(Locale.ROOT);
        String target = parts[1];
        String version = parts[2];
        Map<String, String> headers = new LinkedHashMap<>();
        for (int i = 0; i < 120; i++) {
            String h = readLine(in, 16384);
            if (h == null) return null;
            if (h.isEmpty()) break;
            int c = h.indexOf(':');
            if (c <= 0) continue;
            String k = h.substring(0, c).trim().toLowerCase(Locale.ROOT);
            String v = h.substring(c + 1).trim();
            String old = headers.get(k);
            headers.put(k, old == null ? v : old + ", " + v);
        }
        String te = headers.get("transfer-encoding");
        if (te != null && te.toLowerCase(Locale.ROOT).contains("chunked")) throw new HttpError(411, "Length required");
        long len = 0;
        String cl = headers.get("content-length");
        if (cl != null) {
            try { len = Long.parseLong(cl.trim()); } catch (NumberFormatException e) { throw new HttpError(400, "Bad length"); }
            if (len < 0) throw new HttpError(400, "Bad length");
        }
        String expect = headers.get("expect");
        if (expect != null && expect.toLowerCase(Locale.ROOT).contains("100-continue") && len > 0) {
            out.write("HTTP/1.1 100 Continue\r\n\r\n".getBytes(StandardCharsets.ISO_8859_1));
            out.flush();
        }
        String rawPath = target;
        String rawQuery = "";
        int qi = target.indexOf('?');
        if (qi >= 0) {
            rawPath = target.substring(0, qi);
            rawQuery = target.substring(qi + 1);
        }
        int hash = rawPath.indexOf('#');
        if (hash >= 0) rawPath = rawPath.substring(0, hash);
        if (rawPath.startsWith("http://") || rawPath.startsWith("https://")) {
            int slash = rawPath.indexOf('/', rawPath.indexOf("//") + 2);
            rawPath = slash < 0 ? "/" : rawPath.substring(slash);
        }
        String path = pathDecode(rawPath);
        boolean keep = "HTTP/1.1".equalsIgnoreCase(version);
        String conn = headers.get("connection");
        if (conn != null) {
            String lc = conn.toLowerCase(Locale.ROOT);
            if (lc.contains("close")) keep = false;
            else if (lc.contains("keep-alive")) keep = true;
        }
        return new Request(method, path, rawQuery, headers, ip, loop, in, len, keep);
    }

    static String pathDecode(String s) {
        if (s.indexOf('%') < 0) return s;
        ByteArrayOutputStream b = new ByteArrayOutputStream(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '%' && i + 2 < s.length() + 0 && isHex(s.charAt(i + 1)) && isHex(s.charAt(i + 2))) {
                b.write(Integer.parseInt(s.substring(i + 1, i + 3), 16));
                i += 2;
            } else if (c < 128) {
                b.write(c);
            } else {
                byte[] bytes = String.valueOf(c).getBytes(StandardCharsets.UTF_8);
                b.write(bytes, 0, bytes.length);
            }
        }
        return new String(b.toByteArray(), StandardCharsets.UTF_8);
    }

    private static boolean isHex(char c) {
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
    }

    // ---------------------------------------------------------------- request

    public static final class Request {
        public final String method;
        public final String path;
        public final String rawQuery;
        public final Map<String, String> headers;
        public final String remoteIp;
        public final boolean loopback;
        public final long contentLength;
        final boolean keepAlive;
        private final InputStream raw;
        private long remaining;
        private Map<String, List<String>> query;
        private Map<String, String> cookies;
        private InputStream body;

        Request(String method, String path, String rawQuery, Map<String, String> headers, String ip, boolean loop,
                InputStream raw, long len, boolean keep) {
            this.method = method;
            this.path = path;
            this.rawQuery = rawQuery;
            this.headers = headers;
            this.remoteIp = ip;
            this.loopback = loop;
            this.raw = raw;
            this.contentLength = len;
            this.remaining = len;
            this.keepAlive = keep;
        }

        public String header(String name) {
            return headers.get(name.toLowerCase(Locale.ROOT));
        }

        public Map<String, List<String>> query() {
            if (query == null) {
                query = new LinkedHashMap<>();
                if (!rawQuery.isEmpty()) {
                    for (String kv : rawQuery.split("&")) {
                        if (kv.isEmpty()) continue;
                        int e = kv.indexOf('=');
                        String k = e < 0 ? kv : kv.substring(0, e);
                        String v = e < 0 ? "" : kv.substring(e + 1);
                        try {
                            k = URLDecoder.decode(k, "UTF-8");
                            v = URLDecoder.decode(v, "UTF-8");
                        } catch (Exception ignored) { }
                        List<String> l = query.get(k);
                        if (l == null) {
                            l = new ArrayList<>();
                            query.put(k, l);
                        }
                        l.add(v);
                    }
                }
            }
            return query;
        }

        public String q(String key) {
            List<String> l = query().get(key);
            return l == null || l.isEmpty() ? null : l.get(0);
        }

        public String q(String key, String def) {
            String v = q(key);
            return v == null ? def : v;
        }

        public List<String> qAll(String key) {
            List<String> l = query().get(key);
            return l == null ? new ArrayList<String>() : l;
        }

        public String cookie(String name) {
            if (cookies == null) {
                cookies = new LinkedHashMap<>();
                String c = header("cookie");
                if (c != null) {
                    for (String part : c.split(";")) {
                        int e = part.indexOf('=');
                        if (e <= 0) continue;
                        cookies.put(part.substring(0, e).trim(), part.substring(e + 1).trim());
                    }
                }
            }
            return cookies.get(name);
        }

        /** The request body as a stream limited to Content-Length. */
        public InputStream body() {
            if (body == null) {
                body = new InputStream() {
                    @Override public int read() throws IOException {
                        if (remaining <= 0) return -1;
                        int b = raw.read();
                        if (b >= 0) remaining--;
                        return b;
                    }
                    @Override public int read(byte[] b, int off, int len) throws IOException {
                        if (remaining <= 0) return -1;
                        int n = raw.read(b, off, (int) Math.min(len, remaining));
                        if (n > 0) remaining -= n;
                        return n;
                    }
                    @Override public int available() throws IOException {
                        return (int) Math.min(remaining, raw.available());
                    }
                };
            }
            return body;
        }

        public byte[] readBody(int max) throws IOException {
            if (contentLength > max) throw new HttpError(413, "Request too large");
            ByteArrayOutputStream bo = new ByteArrayOutputStream((int) Math.max(32, contentLength));
            byte[] buf = new byte[8192];
            InputStream b = body();
            int n;
            while ((n = b.read(buf)) > 0) bo.write(buf, 0, n);
            return bo.toByteArray();
        }

        public Map<String, Object> json() throws IOException {
            byte[] raw = readBody(1024 * 1024 * 4);
            if (raw.length == 0) return new LinkedHashMap<>();
            try {
                return Json.parseObject(new String(raw, StandardCharsets.UTF_8));
            } catch (IllegalArgumentException e) {
                throw new HttpError(400, "Bad JSON");
            }
        }

        boolean drainBody() {
            if (remaining <= 0) return true;
            if (remaining > 2 * 1024 * 1024) return false;
            try {
                byte[] buf = new byte[8192];
                InputStream b = body();
                while (b.read(buf) > 0) { /* discard */ }
            } catch (IOException e) {
                return false;
            }
            return remaining <= 0;
        }
    }

    // ---------------------------------------------------------------- response

    public static final class Response {
        private final Request req;
        private final OutputStream out;
        private final LinkedHashMap<String, String> headers = new LinkedHashMap<>();
        private final List<String> cookies = new ArrayList<>();
        boolean headSent;
        boolean finished;
        boolean closeAfter;
        private OutputStream bodyOut;
        private boolean chunked;

        Response(Request req, OutputStream out) {
            this.req = req;
            this.out = out;
        }

        public Response header(String k, String v) {
            headers.put(k, v);
            return this;
        }

        public Response cookie(String setCookie) {
            cookies.add(setCookie);
            return this;
        }

        public boolean isHead() {
            return req != null && req.method.equals("HEAD");
        }

        public void json(int status, Object o) throws IOException {
            bytes(status, "application/json; charset=utf-8", Json.stringify(o).getBytes(StandardCharsets.UTF_8));
        }

        public void text(int status, String contentType, String s) throws IOException {
            bytes(status, contentType, s.getBytes(StandardCharsets.UTF_8));
        }

        public void error(int status, String message) throws IOException {
            headers.remove("Content-Disposition");
            json(status, Json.obj("error", message == null ? "Error" : message));
        }

        public void bytes(int status, String contentType, byte[] body) throws IOException {
            headers.put("Content-Type", contentType);
            ByteArrayOutputStream head = head(status, body.length);
            if (!isHead()) head.write(body, 0, body.length);
            out.write(head.toByteArray());
            out.flush();
            headSent = true;
            finished = true;
        }

        /**
         * Starts a streamed body. A non-negative length sends Content-Length; -1 uses chunked encoding, which lets a
         * browser notice a download that was cut short.
         */
        public OutputStream begin(int status, String contentType, long length) throws IOException {
            if (contentType != null) headers.put("Content-Type", contentType);
            if (length < 0) {
                chunked = true;
                headers.put("Transfer-Encoding", "chunked");
            }
            ByteArrayOutputStream head = head(status, length);
            out.write(head.toByteArray());
            headSent = true;
            if (isHead()) {
                out.flush();
                finished = true;
                return new OutputStream() {
                    @Override public void write(int b) { }
                    @Override public void write(byte[] b, int o, int l) { }
                };
            }
            bodyOut = chunked ? new ChunkedOut(out) : out;
            return new OutputStream() {
                @Override public void write(int b) throws IOException { bodyOut.write(b); }
                @Override public void write(byte[] b, int o, int l) throws IOException { bodyOut.write(b, o, l); }
                @Override public void flush() throws IOException { bodyOut.flush(); }
                @Override public void close() throws IOException { end(); }
            };
        }

        /** Opens a server-sent events stream. The body runs until the connection closes. */
        public OutputStream events() throws IOException {
            closeAfter = true;
            headers.put("Content-Type", "text/event-stream; charset=utf-8");
            headers.put("Cache-Control", "no-cache, no-transform");
            headers.put("X-Accel-Buffering", "no");
            ByteArrayOutputStream head = head(200, -2);
            out.write(head.toByteArray());
            out.flush();
            headSent = true;
            bodyOut = out;
            return new OutputStream() {
                @Override public void write(int b) throws IOException { out.write(b); }
                @Override public void write(byte[] b, int o, int l) throws IOException { out.write(b, o, l); }
                @Override public void flush() throws IOException { out.flush(); }
                @Override public void close() { finished = true; }
            };
        }

        public void end() throws IOException {
            if (finished) return;
            finished = true;
            if (chunked && bodyOut instanceof ChunkedOut) ((ChunkedOut) bodyOut).finish();
            out.flush();
        }

        private ByteArrayOutputStream head(int status, long length) throws IOException {
            ByteArrayOutputStream b = new ByteArrayOutputStream(512);
            StringBuilder sb = new StringBuilder(384);
            sb.append("HTTP/1.1 ").append(status).append(' ').append(reason(status)).append("\r\n");
            sb.append("Server: LocalDrop\r\n");
            sb.append("X-Content-Type-Options: nosniff\r\n");
            sb.append("Referrer-Policy: no-referrer\r\n");
            if (!headers.containsKey("Cache-Control")) sb.append("Cache-Control: no-store\r\n");
            for (Map.Entry<String, String> e : headers.entrySet()) {
                sb.append(e.getKey()).append(": ").append(e.getValue().replace('\r', ' ').replace('\n', ' ')).append("\r\n");
            }
            for (String c : cookies) sb.append("Set-Cookie: ").append(c).append("\r\n");
            if (length >= 0) sb.append("Content-Length: ").append(length).append("\r\n");
            boolean keep = req != null && req.keepAlive && !closeAfter && length != -2;
            if (!keep) closeAfter = true;
            sb.append("Connection: ").append(keep ? "keep-alive" : "close").append("\r\n\r\n");
            b.write(sb.toString().getBytes(StandardCharsets.ISO_8859_1));
            return b;
        }

        private static String reason(int s) {
            switch (s) {
                case 100: return "Continue";
                case 200: return "OK";
                case 201: return "Created";
                case 204: return "No Content";
                case 206: return "Partial Content";
                case 301: return "Moved Permanently";
                case 302: return "Found";
                case 304: return "Not Modified";
                case 400: return "Bad Request";
                case 401: return "Unauthorized";
                case 403: return "Forbidden";
                case 404: return "Not Found";
                case 405: return "Method Not Allowed";
                case 409: return "Conflict";
                case 410: return "Gone";
                case 411: return "Length Required";
                case 413: return "Payload Too Large";
                case 416: return "Range Not Satisfiable";
                case 423: return "Locked";
                case 429: return "Too Many Requests";
                case 431: return "Request Header Fields Too Large";
                case 500: return "Internal Server Error";
                case 507: return "Insufficient Storage";
                default: return "Status";
            }
        }
    }

    /** Buffers output into reasonably sized chunks. */
    private static final class ChunkedOut extends OutputStream {
        private final OutputStream out;
        private final byte[] buf = new byte[16384];
        private int n;
        private boolean done;

        ChunkedOut(OutputStream out) { this.out = out; }

        @Override public void write(int b) throws IOException {
            if (n == buf.length) flushChunk();
            buf[n++] = (byte) b;
        }

        @Override public void write(byte[] b, int off, int len) throws IOException {
            while (len > 0) {
                if (n == buf.length) flushChunk();
                int c = Math.min(len, buf.length - n);
                System.arraycopy(b, off, buf, n, c);
                n += c;
                off += c;
                len -= c;
            }
        }

        private void flushChunk() throws IOException {
            if (n == 0) return;
            out.write((Integer.toHexString(n) + "\r\n").getBytes(StandardCharsets.ISO_8859_1));
            out.write(buf, 0, n);
            out.write(new byte[] {'\r', '\n'});
            n = 0;
        }

        @Override public void flush() throws IOException {
            flushChunk();
            out.flush();
        }

        void finish() throws IOException {
            if (done) return;
            done = true;
            flushChunk();
            out.write("0\r\n\r\n".getBytes(StandardCharsets.ISO_8859_1));
            out.flush();
        }
    }
}
