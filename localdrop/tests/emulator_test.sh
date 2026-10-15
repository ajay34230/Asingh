#!/usr/bin/env bash
# Runs inside an Android emulator on CI: installs the APK, starts it, and checks the real server and screen.
APK="$1"; OUT="${2:-emu-out}"; mkdir -p "$OUT"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
P=com.ajay.localdrop
adb install -r "$APK" || { bad "install"; exit 1; }
ok "APK installs"
adb shell pm grant $P android.permission.POST_NOTIFICATIONS 2>/dev/null
adb shell appops set $P MANAGE_EXTERNAL_STORAGE allow 2>/dev/null
adb logcat -c
adb shell am start -n $P/.MainActivity >/dev/null
adb forward tcp:8080 tcp:8080 >/dev/null
up=0
for i in $(seq 1 40); do
  if curl -fs http://127.0.0.1:8080/api/ping >/dev/null; then up=1; break; fi
  sleep 1
done
[ $up = 1 ] && ok "server answers inside the app" || bad "server did not start"
sleep 6
adb exec-out screencap -p > "$OUT/1-home.png"
curl -fs http://127.0.0.1:8080/api/info > "$OUT/info.json" && grep -q '"host":true' "$OUT/info.json" && ok "host session over loopback" || bad "info"
curl -fs http://127.0.0.1:8080/ | grep -q "LocalDrop" && ok "web page is served from the APK assets" || bad "index"
curl -fs http://127.0.0.1:8080/js/qr.js | grep -q qrMatrix && ok "script assets served" || bad "assets"
H=(-H "X-Requested-With: LocalDrop" -H "Content-Type: application/json")
curl -fs -X POST "${H[@]}" -d '{}' http://127.0.0.1:8080/api/admin/settings > "$OUT/settings.json" && ok "admin settings" || bad "admin settings"
curl -fs "${H[@]}" http://127.0.0.1:8080/api/admin/network > "$OUT/net.json"; echo "addresses: $(cat "$OUT/net.json")"
head -c 300000 /dev/urandom > "$OUT/blob.bin"
curl -fs -X PUT "${H[0]}" --data-binary @"$OUT/blob.bin" "http://127.0.0.1:8080/api/upload?path=&name=blob.bin" >/dev/null && ok "upload" || bad "upload"
curl -fs http://127.0.0.1:8080/api/files?path= | grep -q blob.bin && ok "file listed" || bad "list"
curl -fs "http://127.0.0.1:8080/api/file?path=blob.bin" | cmp - "$OUT/blob.bin" && ok "download matches upload" || bad "download"
# sharing the whole phone storage
curl -fs -X POST "${H[@]}" -d '{"id":"downloads"}' http://127.0.0.1:8080/api/admin/root >/dev/null && ok "share the Downloads folder" || bad "Downloads root (needs all files access)"
curl -fs http://127.0.0.1:8080/api/files?path= >/dev/null && ok "list Downloads" || bad "list Downloads"
adb exec-out screencap -p > "$OUT/2-after.png"
# the app must still be alive and not have crashed
adb shell pidof $P >/dev/null && ok "app process alive" || bad "app crashed"
adb logcat -d > "$OUT/logcat.txt"
grep -q "FATAL EXCEPTION" "$OUT/logcat.txt" && { bad "crash in logcat"; grep -A12 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -30; } || ok "no crashes in logcat"
grep "LocalDropWeb" "$OUT/logcat.txt" | grep -iE "error|uncaught|undefined" | head -10 > "$OUT/js-errors.txt"
[ -s "$OUT/js-errors.txt" ] && { bad "JavaScript errors in the app"; cat "$OUT/js-errors.txt"; } || ok "no JavaScript errors in the WebView"
# foreground service up
adb shell dumpsys activity services $P | grep -q ServerService && ok "foreground service running" || bad "service not running"
# send the app to the background and confirm it keeps serving
adb shell input keyevent KEYCODE_HOME; sleep 3
curl -fs http://127.0.0.1:8080/api/ping >/dev/null && ok "still serving in the background" || bad "stopped in background"
exit $fail
