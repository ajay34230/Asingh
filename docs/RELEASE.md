# Releasing Royal India Ludo

## Signing key (keep it safe)

`build/release/royalludo-release.keystore` (alias `royalludo`) signs every Play Store
upload; the password is in `build/release/keystore-password.txt`. Both are kept out of
git on purpose. **Back them up somewhere safe**: Google Play needs the same key (or
Play App Signing's upload key) for every update.

## Build the Play Store bundle (AAB)

Needs Android SDK, JDK 17 and the Godot 4.3 Android build template in `godot/android/`
(unzip `android_source.zip` from the export templates into `godot/android/build` and
write `4.3.stable` to `godot/android/.build_version`).

```
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=build/release/royalludo-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=royalludo
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>
godot --headless --path godot --export-release "Android Release" ../build/release/RoyalIndiaLudo.aab
```

Bump `version/code` (and `version/name`) in `godot/export_presets.cfg` for each upload.

## Still needed for the Play Store listing
- Privacy policy URL (the game is offline and collects no data; a one-page policy saying so is enough)
- Content rating questionnaire (cartoon fighting between game pieces; no real violence)
- Store graphics: icon 512 px (`godot/assets/icon/icon_512.png`), feature graphic 1024x500, phone screenshots
- Testing on real Android phones before release
