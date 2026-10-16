# LocalDrop

Turn an Android phone into a private file-sharing server. Other phones, tablets and computers on the same Wi-Fi, or on the phone's own hotspot, join from their web browser by typing the address or scanning a QR code. Nothing goes through the internet and nobody needs to install anything.

**Download the APK:** https://github.com/ajay34230/Asingh/releases/download/localdrop-latest/LocalDrop.apk
(Release page: https://github.com/ajay34230/Asingh/releases/tag/localdrop-latest. Every push to the `localdrop-app` branch builds a fresh APK.)

**Windows:** https://github.com/ajay34230/Asingh/releases/download/localdrop-latest/LocalDrop-Windows.zip (unzip, run `LocalDrop.exe`, allow it through the firewall; it opens LocalDrop in the browser and sits in the tray. Built by the `windows` CI job.)

## Install

1. Open the APK link on the phone and install it (Android asks you to allow installs from your browser or file app once).
2. Open LocalDrop. It shows a QR code and an address such as `192.168.1.20:8080`.
3. On the other device, join the same Wi-Fi (or the hotspot shown in the app), then scan the code or type the address into any browser.

Updates install over the old version, because every build is signed with the same key.

## What it does

- **Files**: browse, search, sort, list or grid view, thumbnails, multi-select, upload files and whole folders (drag and drop on a computer), download single files or zips, rename, move, copy, new folder, edit text files, Trash with restore, share links that expire.
- **Viewer**: images (swipe, zoom), video and audio with seeking, PDF, text and code.
- **Drop**: a shared chat (receivers see files arriving live, with percent and speed) for notes, links and files, with private messages to one device.
- **Apps**: other devices can download the LocalDrop installer from the host (Files menu, "Apps to install"). The host can also allow installers of other apps on the phone.
- **Calls**: voice and video calls (mute, camera off, flip camera, speaker, hold, cancel, decline, busy, and group calls: add more people to a call, everyone connects to everyone) between connected devices, straight over the local network (WebRTC; nothing leaves your network). Everyone picks a name when joining. Browsers only allow the camera and microphone on secure pages, so guests open the secure address (the `https://` one shown in the call prompt), accept the certificate warning once, and then call. The host app itself needs no warning.
- **Connection help**: Invite sheet, "Get help" gives tips for several routers and a delay and speed test.
- **Get the app**: guests can download the Android app (APK, no PIN needed) or install LocalDrop as a web app (PWA) from the login screen, Invite sheet or Settings.
- **Nearby phones**: Android phones running LocalDrop on the same Wi-Fi find each other automatically (mDNS) and show a Connect button on the Nearby screen.
- **Nearby**: a live radar of connected devices, who did what, and the host can disconnect a device.
- **Join**: QR code with optional PIN built in, one-tap hotspot from the app, Wi-Fi QR for the hotspot, addresses for every network the phone is on.
- **Security**: PIN (4 to 8 digits, can be turned off in Settings so people join with just a name) with lockout after 5 wrong tries, per-device sign-in, host controls for what guests may do (upload, change files, make links).
- **Look**: light and dark themes, animations (respects the reduced-motion setting), works on phones, tablets and computers.

## Things to know

- Traffic on the local network is plain HTTP (the call page uses a self-signed HTTPS certificate bundled in the app, so browsers warn once), like most local-network tools. Use a PIN, and use a network you trust.
- To share Downloads, Photos or the whole phone, Android needs "All files access". The app asks and explains.
- To keep sharing while the screen is off, allow LocalDrop to ignore battery limits (Settings, "Keep running in the background").
- The signing key in `keystore/` is committed on purpose so that builds from this repository are updates of one another. It is public. Do not treat the APK signature as proof of who built it. For your own distribution, make your own key and change `app/build.gradle`.
- The Android hotspot made by an app (Android's "local-only hotspot") has no internet. Devices that join it can only reach this phone. That is what LocalDrop needs.

## Layout

```
app/src/main/java/com/ajay/localdrop/server/   the HTTP server (plain Java, no libraries)
app/src/main/java/com/ajay/localdrop/          Android app: WebView, foreground service, hotspot
app/src/main/assets/web/                       the web app every device sees (no build step)
desktop/                                       run the same server on a computer for testing
tests/api_test.py                              API tests (78 checks)
```

## Run it on a computer

```
./desktop/run.sh --port 8080 --root ~/Share
```

Needs Java 8 or newer. It prints the address and PIN.

## Build

GitHub Actions builds it (`.github/workflows/android.yml`): the server tests run first, then Gradle builds the signed release APK and publishes it to the `localdrop-latest` release. To build locally you need JDK 17, the Android SDK and Gradle 8.10:

```
cd localdrop && gradle assembleRelease
```
