# Play Store checklist: The Lost Kingdom

Status 2026-11-02: everything that can be prepared without your accounts or phone is done. What is left needs you.

## Done and verified in CI
- Package `com.ajay.lostkingdom`, arm64-v8a only, no permissions requested (verified in the AAB manifest).
- **Target API 36** (Play requires Android 16 / API 36 for new apps since 2026-08-31). Release workflow builds a Gradle AAB with targetSdk 36 and fails if the manifest says otherwise. Run 41394015382 passed; AAB was about 108 MB (limit is 200 MB for the base module).
- Release workflow `release.yml` works end to end. Without your secrets it signs with a throwaway test key (artifact name ends `-TEST-SIGNED`, cannot be uploaded to Play).
- Version: name 0.4.0, code 3 in the Release preset. Increase `version/code` by 1 for every upload.
- Assets are CC0 or self-made (ASSETS.md). No ads, no network, no purchases.
- Store pack in `store/`: 512 icon, 1024x500 feature graphic, 4 screenshots, and `store/LISTING.md` with description text, content rating answers and Data safety answers.
- Privacy policy: `docs/PRIVACY_POLICY.md`.

## Needs YOU (cannot be done from here)
1. **Play developer account** ($25 once, identity verification).
2. **Upload key** (never commit it). On the phone in Termux: `pkg install openjdk-17`, then
   `keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
   then `base64 -w0 upload.jks` and add four GitHub secrets (repo Settings > Secrets and variables > Actions):
   RELEASE_KEYSTORE_B64, RELEASE_KEYSTORE_PASS, RELEASE_KEY_ALIAS, RELEASE_KEY_PASS. Keep a backup of upload.jks and the passwords.
3. **Privacy policy URL**: Play needs a public web page. Easiest: repo Settings > Pages > deploy from a branch > `main` / `/docs`, then use `https://ajay34230.github.io/Asingh/PRIVACY_POLICY`. (Needs this branch merged to main first. The repo is public, so the GitHub blob link also works.)
4. Run Actions > "Release AAB (manual, signed)" > download the AAB > upload to a Closed testing track. Enrol in Play App Signing when asked.
5. Fill the forms using `store/LISTING.md` (listing, content rating, Data safety, target audience).
6. New personal accounts must run a closed test with at least 12 testers for 14 days before applying for production. Rules change, so check the Console.

## Before production (needs a real phone, cannot be faked)
- Fix the crashes and the yellow/brown slab glitch you saw; confirm frame rate, heat and battery on the S10 and at least one other phone.
- Replace the four screenshots in `store/screenshots/` with real phone screenshots (the current ones are software-rendered captures).
- Android 16 behaviour changes for targetSdk 36: edge-to-edge is enforced, and on tablets/foldables (width 600dp+) a locked orientation is ignored. Check the HUD is not covered by the system bars and the game is usable on a tablet.
- Confirm combat shows no blood or gore before answering the content rating form.
