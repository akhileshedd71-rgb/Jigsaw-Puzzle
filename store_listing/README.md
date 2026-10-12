# Piecepop — Google Play publishing kit

App: **Piecepop** · Package: **com.akhileshedd.piecepop** · Release: **1.0.0 (version code 4)**

Developer: **Akhilesh Mahto** · Public support: **akhileshedd@gmail.com**

The signed AAB has passed bundletool validation, signature verification, manifest checks, and 16 KB native-library alignment checks. A universal APK generated from it also passed signature and 16 KB ZIP-alignment checks and contains the full offline catalog. See [validation-report.json](validation-report.json) for the exact bundle hash and results. Native-device execution and Play Console submission remain untested/unsubmitted.

## Listing fields

| Play Console field | Value / file |
| --- | --- |
| App name | `title.txt` — Piecepop: Jigsaw Puzzles |
| Default language | English (United States), unless you prefer another supported language |
| App or game | Game |
| Category | Puzzle |
| Short description | Copy `short-description.txt` (76 characters; limit 80) |
| Full description | Copy `full-description.txt` (under 4,000 characters) |
| Release notes | Copy `release-notes.txt` |
| Support email | akhileshedd@gmail.com |
| App icon | `graphics/icon-512.png` — 512 × 512 PNG |
| Feature graphic | `graphics/feature-1024x500.png` — 1024 × 500 opaque PNG |
| Phone screenshots | Upload the numbered PNG files in `screenshots/`, in order |
| Privacy policy text | [assets/legal/privacy-policy.txt](../assets/legal/privacy-policy.txt) |
| Privacy policy web page | [docs/privacy-policy.html](../docs/privacy-policy.html), ready to host |

The descriptions accurately identify the bundled 44-image library, the rotating daily selection, 28 free images, and 16 images unlocked with earned coins. They do not claim downloadable content, cloud sync, thousands of puzzles, health benefits, or real-money purchases. Listing graphics are excluded from the game's resource imports and exports.

## Publish the privacy policy

Play Console needs a publicly accessible privacy-policy URL. A text file on your computer is not a URL. The complete policy is also available offline in the app under **Settings → Privacy policy**.

One option is GitHub Pages:

1. Open this repository's **Settings → Pages**.
2. Select **Deploy from a branch**, branch **main**, folder **/docs**, and save.
3. Wait for GitHub's Pages deployment, then open the published policy in a private browser window and verify that it works without signing in.
4. If GitHub Pages uses the default repository URL, the expected policy address is `https://akhileshedd71-rgb.github.io/Jigsaw-Puzzle/privacy-policy.html`. Use the URL GitHub actually confirms; this guide does not activate or verify a Pages deployment.
5. Paste the public URL into Play Console's Privacy policy field.

You can instead host the supplied HTML or the full policy text on another public website. Keep the published policy synchronized with the in-app text when the app changes.

## Create and upload the release

1. Create the app in Play Console with the app name and language above. Choose **Game**. A free download fits the current game; set your intended pricing deliberately because converting a free app to paid later is restricted by Google Play.
2. Complete account identity/contact verification and the app's store listing and App content forms. Account verification and any registration fee are handled in your own Play Console account.
3. Create an **Internal testing** release first. Enable **Play App Signing** and let Google generate/manage the app-signing key. The separately supplied private key is the **upload key** for submitting your bundles.
4. Upload the signed `piecepop-1.0.0.aab`. Do not upload a file ending in `-unsigned.aab`, the old debug APK, or the private key backup.
5. Add the release notes and review Play Console's bundle analysis and pre-launch report. Confirm that the detected package is `com.akhileshedd.piecepop`, version name is `1.0.0`, and version code is `4`.
6. Install the internal-test version on a real ARM64 Android phone. Check dragging, zoom, audio, haptics, background/resume, Android back navigation, safe areas, the privacy page, and saved progress after relaunch.
7. Follow any testing requirements shown for your account before requesting production access. New personal accounts may require a closed test with at least 12 testers continuously opted in for 14 days; the current Console determines your exact eligibility and requirements.
8. Select countries/regions and submit a production release for Google's review when those checks are complete. Building a signed AAB does not publish the app or guarantee review approval.

## App content form guidance

These answers describe this source version. Review them again if you add an SDK, ads, accounts, network features, or purchases.

| Topic | Current behavior / recommended answer |
| --- | --- |
| Ads | No ads and no advertising SDK |
| App access | No login, membership, or external credentials. Some pictures unlock with coins earned by completing free puzzles. |
| Data safety | The app does not collect or share user data off-device. Progress, preferences, coins, and unlocks stay in private local storage. Email support is external to the app and described in the privacy policy. Complete the remaining form fields according to this behavior. |
| Data deletion | There is no app account to delete. Clearing app storage or uninstalling removes local game data. Support-email deletion requests go to the public support email. |
| In-app purchases | None. Coins have no monetary value and cannot be purchased or cashed out. |
| Content rating | Complete Google's/IARC's questionnaire yourself. This build contains illustrated scenery, animals, food, space, and dinosaurs; no chat, user-generated content, gambling, real-money purchases, or realistic violence. Do not enter an assumed rating as though it were already assigned. |
| Target audience | Select the actual age groups you intend to serve. This remains the developer's decision. Including children can bring additional Families requirements; artwork alone does not determine your declared audience. |
| Permissions | Vibration is used for optional haptic feedback. No Internet, location, contacts, camera, or microphone permission is requested. Check the final bundle's merged permission report as the authoritative list. |

## Signing backup and future updates

The private upload-key backup is separate from Git and the public publishing kit. It contains `piecepop-upload.p12`, its password file, the public upload certificate, and instructions. Keep it private and retain a secure backup. The alias is `piecepop-upload`. Use the same upload key for subsequent updates, or follow Google's upload-key reset procedure if it is lost.

The store app uses a different application ID from the earlier `com.piecepop.game` debug build. It installs separately and does not migrate that debug app's local saves. Within the new app ID, future updates preserve saves when normal Android update rules are followed. Never uninstall a user's app as an update procedure.

Increase `version/code` in `export_presets.cfg` for every new upload. Change `version/name` when you want a new user-facing version. Keep the application ID unchanged after publishing.

## Build another signed AAB

Install a full JDK 17 or 21 (including `javac`, `keytool`, and `jarsigner`), Godot 4.6.3, and matching export templates. In Godot, install **Project → Install Android Build Template** and configure the full JDK and Android SDK paths in Editor Settings. This project uses the official template's Gradle wrapper; do not commit the generated `android/` directory.

On Linux x64, `python3 tools/install_play_jdk.py --destination /path/to/full-jdk` installs the checksum-verified Temurin JDK used for this release. Then `python3 tools/install_android_sdk.py --sdk-root /path/to/sdk --configure-godot --java-home /path/to/full-jdk --gradle` installs checksum-verified SDK packages. Accept the Android SDK licenses using Android Studio or the SDK tools. Gradle may install the template's pinned NDK if needed for native-library packaging.

Run from the project root:

```sh
python3 tools/build_play_bundle.py \
  --keystore /private/path/piecepop-upload.p12 \
  --password-file /private/path/keystore-password.txt \
  --java-home /path/to/full-jdk
```

The **Google Play** preset intentionally builds unsigned. The helper signs a separate copy with `jarsigner`, verifies the signature, and writes a SHA-256 sidecar. Signing passwords are passed through the child process environment, not command-line arguments or project files. Keep private inputs outside the repository.

Validate a built bundle using Google's official bundletool:

```sh
python3 tools/verify_play_bundle.py \
  --bundle builds/android/piecepop-1.0.0.aab \
  --bundletool /path/to/bundletool-all-1.18.3.jar \
  --java-home /path/to/full-jdk
```

In the managed cloud environment, the full JDK is `/workspace/.godot-tools/jdk-21`; SDK and export templates are under `/workspace/.godot-tools`. Set the usual Godot XDG paths from the project README, plus `XDG_CONFIG_HOME=/workspace/.godot-tools/config`, `ANDROID_USER_HOME=/workspace/.godot-tools/android-user`, and `GRADLE_USER_HOME=/workspace/.godot-tools/gradle`. The local Gradle properties use the inherited network proxy and `/etc/ssl/certs/java/cacerts` for the managed CA trust. Preserve TLS and checksum checks.

## Refresh screenshots

After exporting Web and starting `tools/serve_web.py`, run:

```sh
python3 tests/web_smoke.py --device-scale-factor 2.25 --screenshots builds/play-screenshots
```

This captures actual gameplay at 1080 × 2025 pixels, without enlarging older screenshots. The browser regression also exercises drag, hints, saving, completion, and 400-piece zoom. Copy the selected current captures into the numbered listing files after inspecting them. Browser screenshots demonstrate the game's UI; they do not establish native-device validation.

## Official references

- [Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152)
- [Preview asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151)
- [Data safety form](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [16 KB page-size support](https://developer.android.com/guide/practices/page-sizes)
- [Testing requirements for new personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465)

Google can change these requirements. The cloud network could not retrieve these policy pages during preparation; use the live pages and your Console to confirm current form wording and deadlines before submission.
