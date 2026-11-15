# Play Store checklist: The Lost Kingdom

Status 2026-11-15: everything that can be prepared without your accounts or phone is done. What is left needs you.

## Done in the repo
- Package `com.ajay.lostkingdom`, arm64-v8a only, Android App Bundle (AAB) built by Gradle.
- **Target API 36** (Play requires Android 16 / API 36 for new apps since 2026-08-31). `release.yml` fails if the manifest says otherwise.
- **16 KB page size: FAILS on Godot 4.4.1.** `release.yml` checks every native library in the bundle (run 43727325098 on 2026-11-15 failed it). Google requires 16 KB support for apps targeting Android 15+, and blocks updates without it from 2027-02-01 (https://developer.android.com/guide/practices/page-sizes). Godot added 16 KB support in 4.5 (pull request 106358, NDK r28b); there is no official 4.4.x build with it. The check step turns red but the AAB is still uploaded, so a first closed-testing upload may still work with a Play Console warning. Fix: upgrade the project to Godot 4.5.1 or newer before 2027-02-01.
- **Permissions**: INTERNET (optional character downloads) and VIBRATE (hit feedback). `release.yml` warns if any other permission appears.
- **Version label**: release builds show `release-<commit>` instead of `dev` on screen and in crash reports.
- Version: name 0.4.0, code 3 in the Release preset (`export_presets.cfg`). Nothing has been uploaded yet, so code 3 is fine for the first upload. Increase `version/code` by 1 for every later upload.
- Without your signing secrets the workflow signs with a throwaway test key (artifact name ends `-TEST-SIGNED`, cannot be uploaded to Play).
- No ads, no purchases, no accounts, no analytics. The crash log stays on the phone unless the player copies it out.
- Store pack in `store/`: 512 icon, 1024x500 feature graphic, 4 screenshots, and `store/LISTING.md` with description, content rating answers and Data safety answers (updated 2026-11-15 for downloads, monsters and violence against villagers).
- Privacy policy: `docs/PRIVACY_POLICY.md` (updated 2026-11-15 for the optional downloads from GitHub).
- Self-test passes (3 of 3 runs after the 2026-11-15 fixes to the saddle archery test and the Vaidya clinic bug).

## Needs YOU (cannot be done from here)
1. **Play developer account** ($25 once, identity verification).
2. **Upload key** (never commit it). On the phone in Termux: `pkg install openjdk-17`, then
   `keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
   then `base64 -w0 upload.jks` and add four GitHub secrets (repo Settings > Secrets and variables > Actions):
   RELEASE_KEYSTORE_B64, RELEASE_KEYSTORE_PASS, RELEASE_KEY_ALIAS, RELEASE_KEY_PASS. Keep a backup of upload.jks and the passwords: losing them means you can never update the app without Google support.
3. **Privacy policy URL**: Play needs a public web page. The repo is public, so this link works now: `https://github.com/ajay34230/Asingh/blob/phase-1b-environment-demo/docs/PRIVACY_POLICY.md`. For a cleaner address, turn on GitHub Pages (Settings > Pages) once the branch is merged to `main`.
4. Run Actions > "Release AAB (manual, signed)" > download the AAB > upload to a Closed testing track. Accept Play App Signing when asked.
5. Fill the forms using `store/LISTING.md` (listing, content rating, Data safety, target audience).
6. New personal accounts must run a closed test with at least 12 testers for 14 days before applying for production. Rules change, so check the Console.

## Decide before production
- **Mixamo licence**: Adobe's terms allow Mixamo characters and animations inside a game, but not redistribution as stand-alone files. The downloadable characters are public GLB files on the `dlc` branch, which anyone can fetch directly. That is the riskiest point for a public store release. Safer options: bundle them in the app, or host them where only the game fetches them.

## Before production (needs a real phone, cannot be faked)
- Confirm frame rate, heat and battery on the S10 and at least one other phone.
- Replace the four screenshots in `store/screenshots/` with real phone screenshots (the current ones are software-rendered captures). Include a monster mission and the bow.
- Android 16 behaviour changes for targetSdk 36: edge-to-edge is enforced, and on tablets/foldables (width 600dp+) a locked orientation is ignored. Check the HUD is not covered by the system bars and the game is usable on a tablet.
- Confirm combat shows no blood or gore before answering the content rating form.
