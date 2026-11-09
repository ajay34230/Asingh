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
# the same release, as a signed APK to install directly or share:
godot --headless --path godot --export-release "Android Release APK" ../build/release/RoyalIndiaLudo-release.apk
```

Bump `version/code` (and `version/name`) in `godot/export_presets.cfg` for each upload.

## Still needed for the Play Store listing
- Privacy policy URL (the game is offline and collects no data; a one-page policy saying so is enough)
- Content rating questionnaire (cartoon fighting between game pieces; no real violence)
- Store graphics: icon 512 px (`godot/assets/icon/icon_512.png`), feature graphic 1024x500, phone screenshots
- Testing on real Android phones before release

## Rewarded videos (renting token designs)

Players can rent a token design by watching videos: Rare 1 video = 24 h, Epic 2 videos =
24 h, Legendary 3 videos = 12 h, at most 8 videos a day. Royal Tickets (from daily-reward
days 3 and 7, each new level, and each weekly challenge) rent any design for 24 h, and
each design has one free 15-minute trial.

The game is offline today, so no ad network is linked:

- Debug builds play a clearly labelled 6-second **test video** so the flow can be tried.
- Release builds hide the "Watch video" button until a real provider is set.

To go live, add an ad SDK plugin (for example an AdMob plugin for Godot 4), turn on the
internet permission it needs, and at startup set `RewardedAds.provider` to an object with
`is_ready() -> bool` and `show_rewarded(done: Callable)`, calling `done.call(true)` only
when the video was watched to the end (see `scripts/app/rewarded_ads.gd`). Use your own
ad unit IDs and follow the network's policies, including Google Play's Families policy
if children are in the target audience.
