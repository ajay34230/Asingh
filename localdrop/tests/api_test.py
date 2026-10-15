#!/usr/bin/env python3
"""End-to-end API test for LocalDrop. Start the desktop server first, then run:

    python3 tests/api_test.py --host 127.0.0.1 --guest-host 192.0.2.2 --port 8099 --pin 123456 --root /path/to/root

Requests from 127.0.0.1 count as the host. Requests from any other address of this machine count as a guest.
"""
import argparse
import hashlib
import http.client
import json
import os
import socket
import sys
import threading
import time
import urllib.parse
import zipfile
import io

ap = argparse.ArgumentParser()
ap.add_argument("--host", default="127.0.0.1")
ap.add_argument("--guest-host", default=None)
ap.add_argument("--port", type=int, default=8099)
ap.add_argument("--pin", default="123456")
ap.add_argument("--root", required=True)
args = ap.parse_args()

passed = 0
failed = []


def check(name, cond, extra=""):
    global passed
    if cond:
        passed += 1
        print("  ok   " + name)
    else:
        failed.append(name)
        print("  FAIL " + name + (" -> " + str(extra) if extra else ""))


class Client:
    def __init__(self, host, cookie=None):
        self.host = host
        self.cookie = cookie
        self.conn = http.client.HTTPConnection(host, args.port, timeout=60)

    def req(self, method, path, body=None, headers=None, json_body=None, write=True, raw=False):
        h = {}
        if write and method != "GET" and method != "HEAD":
            h["X-Requested-With"] = "LocalDrop"
        if self.cookie:
            h["Cookie"] = self.cookie
        if json_body is not None:
            body = json.dumps(json_body).encode()
            h["Content-Type"] = "application/json"
        if headers:
            h.update(headers)
        self.conn.request(method, path, body=body, headers=h)
        r = self.conn.getresponse()
        data = r.read()
        sc = r.getheader("Set-Cookie")
        if sc and sc.startswith("ld=") and "Max-Age=0" not in sc:
            self.cookie = sc.split(";")[0]
        if raw:
            return r, data
        try:
            return r.status, (json.loads(data) if data else None), r
        except ValueError:
            return r.status, data, r


host = Client(args.host)

print("Host basics")
st, info, _ = host.req("GET", "/api/info")
check("info as host", st == 200 and info["host"] and info["authed"], info)
st, lst, _ = host.req("GET", "/api/files?path=")
check("list root", st == 200 and any(e["name"] == "hello.txt" for e in lst["entries"]), lst)

print("Uploads and downloads")
payload = os.urandom(5 * 1024 * 1024 + 123)
sha = hashlib.sha256(payload).hexdigest()
st, up, _ = host.req("PUT", "/api/upload?path=&name=" + urllib.parse.quote("big file ñ.bin"), body=payload)
check("upload 5MB", st == 200 and up["size"] == len(payload), up)
name = up["name"]
r, data = host.req("GET", "/api/file?dl=1&path=" + urllib.parse.quote(name), raw=True)
check("download intact", r.status == 200 and hashlib.sha256(data).hexdigest() == sha)
check("attachment disposition", "attachment" in (r.getheader("Content-Disposition") or "") and "filename*=UTF-8''" in r.getheader("Content-Disposition"))
r, data = host.req("GET", "/api/file?path=" + urllib.parse.quote(name), headers={"Range": "bytes=1000-1999"}, raw=True)
check("range 206", r.status == 206 and data == payload[1000:2000] and r.getheader("Content-Range") == "bytes 1000-1999/%d" % len(payload), (r.status, r.getheader("Content-Range")))
r, data = host.req("GET", "/api/file?path=" + urllib.parse.quote(name), headers={"Range": "bytes=-100"}, raw=True)
check("suffix range", r.status == 206 and data == payload[-100:])
r, data = host.req("GET", "/api/file?path=" + urllib.parse.quote(name), headers={"Range": "bytes=99999999-"}, raw=True)
check("range past end -> 416", r.status == 416, r.status)
r, data = host.req("HEAD", "/api/file?path=" + urllib.parse.quote(name), raw=True)
check("HEAD has length and no body", r.status == 200 and data == b"" and int(r.getheader("Content-Length")) == len(payload))
st, up2, _ = host.req("PUT", "/api/upload?path=&name=" + urllib.parse.quote("big file ñ.bin"), body=b"second")
check("name conflict renames", st == 200 and up2["name"] == "big file ñ (1).bin", up2)
st, up3, _ = host.req("PUT", "/api/upload?path=&name=hello.txt&conflict=replace", body=b"replaced")
check("replace conflict", st == 200 and up3["name"] == "hello.txt")
check("replace wrote content", open(os.path.join(args.root, "hello.txt"), "rb").read() == b"replaced")
st, e, _ = host.req("PUT", "/api/upload?path=&name=" + urllib.parse.quote("../evil.txt"), body=b"x")
check("reject .. in name", st == 400, (st, e))
st, e, _ = host.req("PUT", "/api/upload?path=" + urllib.parse.quote("../..") + "&name=a.txt", body=b"x")
check("reject .. in path", st == 400, (st, e))
st, e, _ = host.req("PUT", "/api/upload?path=&rel=" + urllib.parse.quote("../x") + "&name=a.txt", body=b"x")
check("reject .. in rel", st == 400, (st, e))
st, e, _ = host.req("PUT", "/api/upload?path=&rel=" + urllib.parse.quote("My Album/2024") + "&name=pic.jpg", body=b"jpgdata")
check("folder upload creates subfolders", st == 200 and os.path.isfile(os.path.join(args.root, "My Album", "2024", "pic.jpg")), (st, e))
st, e, _ = host.req("GET", "/api/file?path=" + urllib.parse.quote(".localdrop/trash.json"))
check("hidden internals blocked", st == 403, st)
leftovers = [f for f in os.listdir(args.root) if f.endswith(".ldpart") or f.startswith(".ld-")]
check("no temp files left", not leftovers, leftovers)

print("Interrupted upload leaves nothing behind")
s = socket.create_connection((args.host, args.port))
s.sendall(("PUT /api/upload?path=&name=partial.bin HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Requested-With: LocalDrop\r\nContent-Length: 100000\r\n\r\n").encode() + b"x" * 1000)
time.sleep(0.3)
s.close()
time.sleep(0.8)
check("partial not published", not os.path.exists(os.path.join(args.root, "partial.bin")))
leftovers = [f for f in os.listdir(args.root) if f.endswith(".ldpart")]
check("partial temp cleaned", not leftovers, leftovers)

print("Folders, rename, move, copy")
st, e, _ = host.req("POST", "/api/mkdir", json_body={"path": "", "name": "Docs"})
check("mkdir", st == 200 and os.path.isdir(os.path.join(args.root, "Docs")), (st, e))
st, e, _ = host.req("POST", "/api/mkdir", json_body={"path": "", "name": "Docs"})
check("mkdir duplicate -> 409", st == 409, st)
st, e, _ = host.req("POST", "/api/mkdir", json_body={"path": "", "name": "a/b"})
check("mkdir slash rejected", st == 400, st)
st, e, _ = host.req("POST", "/api/rename", json_body={"path": "Docs", "name": "Papers"})
check("rename folder", st == 200 and os.path.isdir(os.path.join(args.root, "Papers")), (st, e))
st, e, _ = host.req("POST", "/api/move", json_body={"paths": ["hello.txt"], "dest": "Papers"})
check("move file", st == 200 and os.path.isfile(os.path.join(args.root, "Papers", "hello.txt")), (st, e))
st, e, _ = host.req("POST", "/api/move", json_body={"paths": ["Papers/hello.txt"], "dest": "", "copy": True})
check("copy file", st == 200 and os.path.isfile(os.path.join(args.root, "hello.txt")) and os.path.isfile(os.path.join(args.root, "Papers", "hello.txt")), (st, e))
st, e, _ = host.req("POST", "/api/move", json_body={"paths": ["Papers"], "dest": "Papers"})
check("folder into itself rejected", st == 400, (st, e))

print("Zip")
r, data = host.req("GET", "/api/zip?path=Papers&path=" + urllib.parse.quote("My Album"), raw=True)
z = zipfile.ZipFile(io.BytesIO(data))
names = z.namelist()
check("zip streams and opens", r.status == 200 and z.testzip() is None, r.status)
check("zip has nested files", "Papers/hello.txt" in names and "My Album/2024/pic.jpg" in names, names)
check("zip uses chunked encoding", (r.getheader("Transfer-Encoding") or "") == "chunked")

print("Trash")
st, e, _ = host.req("POST", "/api/delete", json_body={"paths": ["Papers/hello.txt"]})
check("delete to trash", st == 200 and not os.path.exists(os.path.join(args.root, "Papers", "hello.txt")), (st, e))
st, tr, _ = host.req("GET", "/api/trash")
check("trash lists item", st == 200 and len(tr) >= 1 and tr[0]["name"] == "hello.txt", tr)
st, e, _ = host.req("POST", "/api/trash/restore", json_body={"ids": [tr[0]["id"]]})
check("restore", st == 200 and os.path.isfile(os.path.join(args.root, "Papers", "hello.txt")), (st, e))
st, e, _ = host.req("POST", "/api/delete", json_body={"paths": [""]})
check("cannot delete root", st == 400, (st, e))
trash_files = []
for dp, dn, fn in os.walk(os.path.join(args.root, ".localdrop")):
    trash_files += fn
st, lst, _ = host.req("GET", "/api/files?path=")
check("internals hidden from listing", not any(e["name"].startswith(".localdrop") for e in lst["entries"]))

print("Text editing")
st, e, _ = host.req("POST", "/api/newfile", json_body={"path": "Papers", "name": "note.md", "content": "# Hi\nline"})
check("new text file", st == 200, (st, e))
st, t, _ = host.req("GET", "/api/text?path=Papers/note.md")
check("read text", st == 200 and t["content"] == "# Hi\nline", t)
st, e, _ = host.req("PUT", "/api/text", json_body={"path": "Papers/note.md", "content": "changed"})
check("save text", st == 200 and open(os.path.join(args.root, "Papers", "note.md")).read() == "changed", (st, e))
st, e, _ = host.req("GET", "/api/text?path=" + urllib.parse.quote(name))
check("binary refused as text", st in (413, 415), st)

print("Search")
st, s_, _ = host.req("GET", "/api/search?q=pic&path=")
check("search finds nested file", st == 200 and any(e["name"] == "pic.jpg" for e in s_["entries"]), s_)

print("Security headers and CSRF")
r, data = host.req("POST", "/api/mkdir", body=json.dumps({"path": "", "name": "csrf"}).encode(), write=False, raw=True)
check("write without custom header is refused", r.status == 403, r.status)
r, data = host.req("GET", "/api/info", headers={"Host": "evil.example"}, raw=True)
check("loopback with foreign Host header is refused (anti DNS rebinding)", r.status == 403, r.status)
r, data = host.req("POST", "/api/mkdir", body=b"{}", headers={"Origin": "http://evil.example"}, raw=True)
check("foreign Origin refused", r.status == 403, r.status)
html = open(os.path.join(args.root, "evil.html"), "wb")
html.write(b"<script>alert(1)</script>")
html.close()
r, data = host.req("GET", "/api/file?path=evil.html", raw=True)
check("html is never rendered inline", "attachment" in (r.getheader("Content-Disposition") or ""), r.getheader("Content-Disposition"))
r, data = host.req("GET", "/", raw=True)
check("CSP on index", "script-src 'self'" in (r.getheader("Content-Security-Policy") or ""))

print("Messages")
st, m, _ = host.req("POST", "/api/messages", json_body={"text": "hello from host"})
check("post message", st == 200 and m["text"] == "hello from host", (st, m))
st, m2, _ = host.req("POST", "/api/messages", json_body={"text": "see file", "file": {"path": "Papers/note.md"}})
check("message with file", st == 200 and m2["file"]["name"] == "note.md", (st, m2))
st, ml, _ = host.req("GET", "/api/messages")
check("list messages", st == 200 and len(ml) >= 2)

print("Share link")
st, sh, _ = host.req("POST", "/api/share", json_body={"path": "Papers/note.md", "hours": 1})
check("create share", st == 200 and sh["url"].startswith("/s/"), (st, sh))

if args.guest_host:
    print("Guest access")
    g = Client(args.guest_host)
    st, gi, _ = g.req("GET", "/api/info")
    check("guest sees PIN prompt", st == 200 and gi["pinRequired"] and not gi["authed"], gi)
    st, e, _ = g.req("GET", "/api/files?path=")
    check("guest blocked without login", st == 401, st)
    st, e, _ = g.req("POST", "/api/login", json_body={"pin": "000000", "deviceId": "guest-device-0001", "name": "Test phone", "kind": "phone"})
    check("wrong PIN refused", st == 401, (st, e))
    st, e, _ = g.req("POST", "/api/login", json_body={"pin": args.pin, "deviceId": "guest-device-0001", "name": "Test phone", "kind": "phone"})
    check("correct PIN signs in", st == 200 and g.cookie, (st, e))
    st, gi, _ = g.req("GET", "/api/info")
    check("guest authed", gi["authed"] and not gi["host"] and gi["you"]["name"] == "Test phone", gi)
    st, lst, _ = g.req("GET", "/api/files?path=")
    check("guest can list", st == 200)
    st, e, _ = g.req("GET", "/api/files?path=" + urllib.parse.quote("../"))
    check("guest traversal blocked", st == 400, (st, e))
    st, e, _ = g.req("GET", "/api/admin/settings")
    check("guest cannot read admin settings", st == 403, st)
    st, e, _ = g.req("POST", "/api/admin/regen-pin")
    check("guest cannot regenerate PIN", st == 403, st)
    st, e, _ = g.req("PUT", "/api/upload?path=&name=from-guest.txt", body=b"guest data")
    check("guest upload", st == 200 and os.path.isfile(os.path.join(args.root, "from-guest.txt")), (st, e))
    st, e, _ = g.req("POST", "/api/delete", json_body={"paths": ["from-guest.txt"], "permanent": True})
    check("guest cannot delete permanently", st == 403, st)

    st, dv, _ = host.req("GET", "/api/devices")
    check("host sees guest device", any(d["id"] == "guest-device-0001" for d in dv), dv)

    # live events
    got = []
    def listen():
        c = socket.create_connection((args.guest_host, args.port), timeout=10)
        c.sendall(("GET /api/events HTTP/1.1\r\nHost: x\r\nCookie: %s\r\n\r\n" % g.cookie).encode())
        buf = b""
        end = time.time() + 6
        while time.time() < end and b"chat-ping" not in buf:
            try:
                buf += c.recv(4096)
            except socket.timeout:
                break
        got.append(buf)
        c.close()
    th = threading.Thread(target=listen)
    th.start()
    time.sleep(1.0)
    host.req("POST", "/api/messages", json_body={"text": "chat-ping"})
    th.join()
    text = got[0].decode("utf-8", "replace") if got else ""
    check("events stream says hello", "event: hello" in text)
    check("events stream delivers new messages", "event: message" in text and "chat-ping" in text, text[-300:])

    # private messages
    st, pm, _ = g.req("POST", "/api/messages", json_body={"text": "secret for host", "to": "host"})
    check("private message sent", st == 200, (st, pm))
    other = Client(args.guest_host)
    other.req("POST", "/api/login", json_body={"pin": args.pin, "deviceId": "guest-device-0002", "name": "Other", "kind": "laptop"})
    st, ml, _ = other.req("GET", "/api/messages")
    check("other guest does not see private message", not any(x["text"] == "secret for host" for x in ml))
    st, ml, _ = host.req("GET", "/api/messages")
    check("recipient sees private message", any(x["text"] == "secret for host" for x in ml))

    # share link works without a cookie
    anon = Client(args.guest_host)
    r, data = anon.req("GET", sh["url"], raw=True)
    check("share link downloads without sign-in", r.status == 200 and data == b"changed", r.status)
    r, data = anon.req("GET", "/s/doesnotexist/x", raw=True)
    check("bad share token -> 404", r.status == 404)

    # brute force protection
    b = Client(args.guest_host)
    codes = []
    for i in range(7):
        st, e, _ = b.req("POST", "/api/login", json_body={"pin": "11111%d" % i, "deviceId": "guest-device-0003", "name": "Bad"})
        codes.append(st)
    check("PIN guessing is rate limited", codes[-1] == 429 and codes[0] == 401, codes)
    st, e, _ = b.req("POST", "/api/login", json_body={"pin": args.pin, "deviceId": "guest-device-0003", "name": "Bad"})
    check("lockout also blocks the right PIN for a while", st == 429, st)

    # host controls
    st, e, _ = host.req("POST", "/api/admin/settings", json_body={"guestUpload": False, "guestModify": False})
    check("host turns off guest changes", st == 200)
    st, e, _ = g.req("PUT", "/api/upload?path=&name=blocked.txt", body=b"x")
    check("guest upload now refused", st == 403, st)
    st, e, _ = g.req("POST", "/api/mkdir", json_body={"path": "", "name": "nope"})
    check("guest mkdir now refused", st == 403, st)
    host.req("POST", "/api/admin/settings", json_body={"guestUpload": True, "guestModify": True})
    st, e, _ = host.req("POST", "/api/devices/kick", json_body={"id": "guest-device-0001"})
    check("host kicks a device", st == 200)
    st, e, _ = g.req("GET", "/api/files?path=")
    check("kicked device is signed out", st == 401, st)
    st, e, _ = host.req("POST", "/api/admin/regen-pin")
    check("regenerate PIN", st == 200 and len(e["pin"]) == 6 and e["pin"] != args.pin, e)

print("Keep-alive")
c = Client(args.host)
ok = True
for i in range(30):
    st, e, _ = c.req("GET", "/api/ping")
    ok = ok and st == 200
check("30 requests on one connection", ok)

print("Concurrent same-name uploads")
results = []
def up_one(i):
    cl = Client(args.host)
    st, e, _ = cl.req("PUT", "/api/upload?path=&name=race.txt", body=("data%d" % i).encode())
    results.append((st, e))
ths = [threading.Thread(target=up_one, args=(i,)) for i in range(8)]
[t.start() for t in ths]
[t.join() for t in ths]
names = sorted(e["name"] for st, e in results if st == 200)
check("8 uploads, 8 distinct files", len(set(names)) == 8, names)

print("\n%d passed, %d failed" % (passed, len(failed)))
if failed:
    print("Failed:", failed)
    sys.exit(1)
