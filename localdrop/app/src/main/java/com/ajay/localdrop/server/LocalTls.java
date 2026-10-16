package com.ajay.localdrop.server;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.math.BigInteger;
import java.net.InetAddress;
import java.net.Socket;
import java.nio.file.Files;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.security.Signature;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.ECGenParameterSpec;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.TimeZone;
import java.util.concurrent.Callable;
import javax.net.ssl.KeyManager;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.X509ExtendedKeyManager;

/**
 * HTTPS that browsers can really trust.
 *
 * Each install makes its own private certificate authority (CA) the first time it runs. The CA key never leaves the
 * device. Other devices install the CA certificate once (it is offered at /api/ca) and from then on the address
 * of this device, whatever Wi-Fi it is on, has a valid certificate: the server signs a fresh certificate for its
 * current addresses whenever they change. The CA is limited, with the X.509 name-constraints extension, to private
 * network addresses, so even if someone trusts it, it cannot vouch for a website on the internet.
 *
 * Plain JDK only (no extra libraries), so it works the same on Android, Windows and Linux.
 */
public final class LocalTls {
    private static final SecureRandom RNG = new SecureRandom();
    private static final String SIG_OID = "1.2.840.10045.4.3.2"; // ecdsa-with-SHA256

    private final File dir;
    private final Callable<List<String>> addresses;
    private PrivateKey caKey;
    private X509Certificate caCert;
    private byte[] caDer;

    // the current server certificate
    private PrivateKey leafKey;
    private X509Certificate leaf;
    private List<String> leafIps = new ArrayList<>();
    private long leafMade;

    public LocalTls(File dir, Callable<List<String>> addresses) throws Exception {
        this.dir = dir;
        this.addresses = addresses;
        loadOrCreateCa();
    }

    /** The CA certificate in DER form, for other devices to install. */
    public byte[] caCertificate() { return caDer.clone(); }

    /** SHA-256 of the CA certificate, shown so people can check they installed the right one. */
    public String caFingerprint() {
        try {
            byte[] d = MessageDigest.getInstance("SHA-256").digest(caDer);
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < d.length; i++) {
                if (i > 0) sb.append(':');
                sb.append(String.format("%02X", d[i] & 0xff));
            }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    public SSLContext context() throws Exception {
        SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(new KeyManager[] {new Keys()}, null, null);
        return ctx;
    }

    // ---------------------------------------------------------------- key manager

    private final class Keys extends X509ExtendedKeyManager {
        @Override public String[] getServerAliases(String keyType, java.security.Principal[] issuers) {
            return keyType != null && keyType.startsWith("EC") ? new String[] {"ld"} : null;
        }
        @Override public String chooseServerAlias(String keyType, java.security.Principal[] issuers, Socket socket) {
            return keyType != null && keyType.startsWith("EC") ? "ld" : null;
        }
        @Override public String chooseEngineServerAlias(String keyType, java.security.Principal[] issuers, SSLEngine engine) {
            return keyType != null && keyType.startsWith("EC") ? "ld" : null;
        }
        @Override public java.security.cert.X509Certificate[] getCertificateChain(String alias) {
            try { return new X509Certificate[] {current()}; } catch (Exception e) { return null; }
        }
        @Override public PrivateKey getPrivateKey(String alias) {
            try { current(); synchronized (LocalTls.this) { return leafKey; } } catch (Exception e) { return null; }
        }
        @Override public String[] getClientAliases(String keyType, java.security.Principal[] issuers) { return null; }
        @Override public String chooseClientAlias(String[] keyType, java.security.Principal[] issuers, Socket socket) { return null; }
    }

    /** The certificate for this device's current addresses; made again when they change or it gets old. */
    private synchronized X509Certificate current() throws Exception {
        List<String> now = new ArrayList<>();
        try {
            List<String> a = addresses.call();
            if (a != null) for (String ip : a) if (ip != null && ip.matches("\\d+\\.\\d+\\.\\d+\\.\\d+") && !now.contains(ip)) now.add(ip);
        } catch (Exception ignored) { /* use what we have */ }
        if (!now.contains("127.0.0.1")) now.add("127.0.0.1");
        boolean stale = leaf == null || System.currentTimeMillis() - leafMade > 20L * 86400000L || !leafIps.containsAll(now);
        if (stale) {
            // keep the addresses seen before too, so a short network change doesn't invalidate earlier ones
            for (String ip : leafIps) if (!now.contains(ip) && now.size() < 12) now.add(ip);
            KeyPairGenerator g = KeyPairGenerator.getInstance("EC");
            g.initialize(new ECGenParameterSpec("secp256r1"), RNG);
            KeyPair kp = g.generateKeyPair();
            byte[] der = makeLeaf(kp, now);
            leaf = (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(new ByteArrayInputStream(der));
            leafKey = kp.getPrivate();
            leafIps = now;
            leafMade = System.currentTimeMillis();
        }
        return leaf;
    }

    // ---------------------------------------------------------------- the CA

    private void loadOrCreateCa() throws Exception {
        File kf = new File(dir, "ca.key");
        File cf = new File(dir, "ca.crt");
        if (kf.isFile() && cf.isFile()) {
            try {
                caKey = KeyFactory.getInstance("EC").generatePrivate(new PKCS8EncodedKeySpec(Files.readAllBytes(kf.toPath())));
                caDer = Files.readAllBytes(cf.toPath());
                caCert = (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(new ByteArrayInputStream(caDer));
                caCert.checkValidity();
                return;
            } catch (Exception broken) {
                // fall through and make a new one
            }
        }
        KeyPairGenerator g = KeyPairGenerator.getInstance("EC");
        g.initialize(new ECGenParameterSpec("secp256r1"), RNG);
        KeyPair kp = g.generateKeyPair();
        String id = new BigInteger(32, RNG).toString(16).toUpperCase();
        byte[] name = name("LocalDrop local CA " + id);
        byte[] tbs = seq(
                tag(0xA0, integer(BigInteger.valueOf(2))),
                integer(serial()),
                algId(),
                name,
                seq(time(daysFromNow(-1)), time(daysFromNow(365 * 20))),
                name,
                kp.getPublic().getEncoded(),
                tag(0xA3, seq(
                        ext("2.5.29.19", true, seq(bool(true))),
                        ext("2.5.29.15", true, bits(new byte[] {0x06}, 1)),
                        ext("2.5.29.30", true, nameConstraints()))));
        caDer = sign(tbs, kp.getPrivate());
        caKey = kp.getPrivate();
        caCert = (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(new ByteArrayInputStream(caDer));
        //noinspection ResultOfMethodCallIgnored
        dir.mkdirs();
        Files.write(kf.toPath(), caKey.getEncoded());
        Files.write(cf.toPath(), caDer);
        try { //noinspection ResultOfMethodCallIgnored
            kf.setReadable(false, false); kf.setReadable(true, true); kf.setWritable(false, false); kf.setWritable(true, true);
        } catch (Exception ignored) { /* best effort */ }
    }

    private byte[] makeLeaf(KeyPair kp, List<String> ips) throws Exception {
        byte[] subject = name("LocalDrop host");
        List<byte[]> names = new ArrayList<>();
        names.add(tlv(0x82, "localhost".getBytes("US-ASCII")));
        names.add(tlv(0x82, "localdrop".getBytes("US-ASCII")));
        for (String ip : ips) if (permitted(ip)) names.add(tlv(0x87, ipBytes(ip)));
        byte[] san = seq(names.toArray(new byte[0][]));
        byte[] tbs = seq(
                tag(0xA0, integer(BigInteger.valueOf(2))),
                integer(serial()),
                algId(),
                caCert.getSubjectX500Principal().getEncoded(),
                seq(time(daysFromNow(-1)), time(daysFromNow(365))),
                subject,
                kp.getPublic().getEncoded(),
                tag(0xA3, seq(
                        ext("2.5.29.19", true, seq()),
                        ext("2.5.29.15", true, bits(new byte[] {(byte) 0x80}, 7)),
                        ext("2.5.29.37", false, seq(oid("1.3.6.1.5.5.7.3.1"))),
                        ext("2.5.29.17", false, san))));
        return sign(tbs, caKey);
    }

    /** An address inside the ranges the CA is allowed to vouch for. One address outside would make the whole certificate invalid. */
    private static boolean permitted(String ip) {
        String[] p = ip.split("\\.");
        if (p.length != 4) return false;
        int a, b;
        try { a = Integer.parseInt(p[0]); b = Integer.parseInt(p[1]); } catch (NumberFormatException e) { return false; }
        return a == 10 || a == 127 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) || (a == 169 && b == 254) || (a == 100 && b >= 64 && b <= 127);
    }

    /** The CA may only vouch for private-network addresses and localhost. */
    private static byte[] nameConstraints() throws IOException {
        int[][] nets = {{10, 0, 0, 0, 255, 0, 0, 0}, {172, 16, 0, 0, 255, 240, 0, 0}, {192, 168, 0, 0, 255, 255, 0, 0},
                {169, 254, 0, 0, 255, 255, 0, 0}, {100, 64, 0, 0, 255, 192, 0, 0}, {127, 0, 0, 0, 255, 0, 0, 0}};
        List<byte[]> subtrees = new ArrayList<>();
        for (int[] n : nets) {
            byte[] b = new byte[8];
            for (int i = 0; i < 8; i++) b[i] = (byte) n[i];
            subtrees.add(seq(tlv(0x87, b)));
        }
        subtrees.add(seq(tlv(0x82, "localhost".getBytes("US-ASCII"))));
        subtrees.add(seq(tlv(0x82, "localdrop".getBytes("US-ASCII"))));
        return seq(tag(0xA0, concat(subtrees.toArray(new byte[0][]))));
    }

    private static byte[] sign(byte[] tbs, PrivateKey key) throws Exception {
        Signature s = Signature.getInstance("SHA256withECDSA");
        s.initSign(key);
        s.update(tbs);
        byte[] sig = s.sign();
        return seq(tbs, algId(), bits(sig, 0));
    }

    // ---------------------------------------------------------------- minimal DER

    private static byte[] ipBytes(String ip) throws Exception {
        return InetAddress.getByName(ip).getAddress();
    }

    private static BigInteger serial() {
        return new BigInteger(120, RNG).add(BigInteger.ONE);
    }

    private static byte[] algId() throws IOException { return seq(oid(SIG_OID)); }

    private static byte[] name(String cn) throws IOException {
        return seq(tag(0x31, seq(oid("2.5.4.3"), tlv(0x0C, cn.getBytes("UTF-8")))));
    }

    private static byte[] ext(String oid, boolean critical, byte[] value) throws IOException {
        return critical ? seq(oid(oid), bool(true), tlv(0x04, value)) : seq(oid(oid), tlv(0x04, value));
    }

    private static byte[] bool(boolean v) { return new byte[] {0x01, 0x01, (byte) (v ? 0xFF : 0x00)}; }

    private static byte[] bits(byte[] v, int unused) throws IOException {
        byte[] b = new byte[v.length + 1];
        b[0] = (byte) unused;
        System.arraycopy(v, 0, b, 1, v.length);
        return tlv(0x03, b);
    }

    private static byte[] integer(BigInteger v) throws IOException { return tlv(0x02, v.toByteArray()); }

    private static byte[] oid(String dotted) throws IOException {
        String[] p = dotted.split("\\.");
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        o.write(Integer.parseInt(p[0]) * 40 + Integer.parseInt(p[1]));
        for (int i = 2; i < p.length; i++) {
            long v = Long.parseLong(p[i]);
            int n = 0;
            byte[] tmp = new byte[10];
            do { tmp[n++] = (byte) (v & 0x7f); v >>= 7; } while (v > 0);
            for (int k = n - 1; k >= 0; k--) o.write(tmp[k] | (k > 0 ? 0x80 : 0));
        }
        return tlv(0x06, o.toByteArray());
    }

    private static Date daysFromNow(int d) {
        return new Date(System.currentTimeMillis() + d * 86400000L);
    }

    private static byte[] time(Date d) throws IOException {
        Calendar c = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        c.setTime(d);
        int y = c.get(Calendar.YEAR);
        String body = String.format("%02d%02d%02d%02d%02d%02dZ", y % 100, c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
                c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE), c.get(Calendar.SECOND));
        if (y >= 2050) return tlv(0x18, (String.format("%04d", y) + body.substring(2)).getBytes("US-ASCII"));
        return tlv(0x17, body.getBytes("US-ASCII"));
    }

    private static byte[] seq(byte[]... parts) throws IOException { return tlv(0x30, concat(parts)); }

    private static byte[] tag(int t, byte[] inner) throws IOException { return tlv(t, inner); }

    private static byte[] concat(byte[]... parts) throws IOException {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        for (byte[] p : parts) o.write(p);
        return o.toByteArray();
    }

    private static byte[] tlv(int tag, byte[] v) throws IOException {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        o.write(tag);
        int n = v.length;
        if (n < 128) o.write(n);
        else if (n < 256) { o.write(0x81); o.write(n); }
        else if (n < 65536) { o.write(0x82); o.write(n >> 8); o.write(n & 0xff); }
        else { o.write(0x83); o.write(n >> 16); o.write((n >> 8) & 0xff); o.write(n & 0xff); }
        o.write(v);
        return o.toByteArray();
    }
}
