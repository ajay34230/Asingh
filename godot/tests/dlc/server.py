"""Test server for the DLC manager: serves a manifest and a pack with HTTP Range support,
and cuts the first pack download off at ~40% to force a resume."""
import hashlib, http.server, json, os, sys, threading

PCK = open(sys.argv[1], "rb").read()
PORT = int(sys.argv[2])
sha = hashlib.sha256(PCK).hexdigest()
cut_once = {"done": False}
log = open(sys.argv[3], "w")

def manifest():
    base = "http://127.0.0.1:%d" % PORT
    return json.dumps({"schema": 1, "packs": [
        {"id": "test_pack", "name": "Test Pack", "version": "1.0.0", "size": len(PCK), "sha256": sha, "url": base + "/pack.pck", "min_game_version": "1.0.0"},
        {"id": "bad_pack", "name": "Bad Checksum", "version": "1.0.0", "size": len(PCK), "sha256": "0" * 64, "url": base + "/pack.pck", "min_game_version": "1.0.0"},
        {"id": "future_pack", "name": "Needs New Game", "version": "1.0.0", "size": 10, "sha256": sha, "url": base + "/pack.pck", "min_game_version": "99.0.0"},
    ]}).encode()

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path == "/manifest.json":
            data = manifest()
            self.send_response(200); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
        if self.path != "/pack.pck":
            self.send_response(404); self.end_headers(); return
        rng = self.headers.get("Range")
        log.write("GET pack range=%s\n" % rng); log.flush()
        start = 0
        if rng and rng.startswith("bytes="):
            start = int(rng[6:].split("-")[0])
        body = PCK[start:]
        self.send_response(206 if rng else 200)
        if rng:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, len(PCK) - 1, len(PCK)))
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if not cut_once["done"] and not rng:
            cut_once["done"] = True
            self.wfile.write(body[: int(len(body) * 0.4)]); self.wfile.flush()
            self.connection.close(); return          # cut the connection mid-download
        self.wfile.write(body)

http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
