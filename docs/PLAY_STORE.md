# Play Store checklist: The Lost Kingdom

## Already done
- Package `com.ajay.lostkingdom`, arm64 only, debug APK builds in CI.
- All assets CC0 or self-made (see ASSETS.md). No ads, no network, no permissions.
- Release preset "Android Release" (AAB, Gradle) and manual workflow `release.yml` (UNTESTED until secrets exist).
- Privacy policy text: docs/PRIVACY_POLICY.md (needs a public URL: enable GitHub Pages or use the raw repo page).

## Needs YOU
1. **Google Play developer account** (one-time fee, identity verification).
2. **Upload key**: generate once (never commit it):
   `keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
   (Termux on the phone can do this: `pkg install openjdk-17`). Then `base64 -w0 upload.jks`.
   Add GitHub secrets: RELEASE_KEYSTORE_B64, RELEASE_KEYSTORE_PASS, RELEASE_KEY_ALIAS, RELEASE_KEY_PASS.
   Enrol in Play App Signing so Google holds the real signing key.
3. Run Actions -> "Release AAB (manual, signed)", download the AAB, upload to an internal-testing track.
4. Store listing: title, short and full description, 512x512 icon, 1024x500 feature graphic,
   at least 2 phone screenshots (CI uploads screenshots), content rating questionnaire,
   Data safety form (answer: no data collected), target audience (not for children), privacy policy URL.
5. New personal accounts must run a closed test with 12+ testers for 14 days before production.

## Technical to-do before production
- Test on a real phone: frame rate, heat, battery, memory, touch comfort.
- Reduce APK/AAB size if needed (textures, audio). Target < 150 MB; currently ~41 MB APK.
- Add save/load, settings menu (volume, quality), pause button.
- Replace the placeholder icon.
