# Android release — Play Console internal track

Issue #14 checklist. The repo-addressable parts (icon, splash, signing
scaffold, versioning, R8/ProGuard) are committed; the remaining steps are
human (keystore, physical device, Play Console). Track them here.

## 1. One-time setup (human)

### 1.1 Release keystore

Create a keystore and record it in `android/key.properties` (gitignored —
never commit it):

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=rogsheba
storeFile=<path-to-upload-keystore.jks>
```

`android/app/build.gradle.kts` reads these at build time. When
`key.properties` is absent (CI, fresh checkout) the release build falls back
to debug signing so `flutter build apk --release` still produces an
installable artifact — but **a debug-signed APK cannot be uploaded to Play
Console**.

### 1.2 Versions

`pubspec.yaml` holds `version: <name>+<build>`:

- `versionName` (shown in Play Console) = `<name>`, e.g. `1.0.0`.
- `versionCode` (monotonic per upload) = `<build>`. Increment it for every
  internal-track upload.

### 1.3 Play Console

Create the app in the Play Console (Google Play Console → Create app), then
link it to the bundle/APK uploaded in §3.

## 2. Build

```sh
flutter build apk --release
# or the AAB recommended for Play:
flutter build appbundle --release
```

R8 + resource shrinking run against `android/app/proguard-rules.pro`, which
keeps the plugin channels (`speech_to_text`, `flutter_tts`,
`permission_handler`, `geolocator`, `shared_preferences`, `dio`) and the Flutter
embedding + Play Core split-install classes intact. Verified locally with
`flutter build apk --release` (succeeds; APK ≈ 53 MB).

## 3. Upload (human)

1. Play Console → your app → **Internal testing** → **Create new release**.
2. Upload the AAB from §2 and confirm the version.
3. Add internal testers (email list) and **Promote to testing**.

## 4. Data Safety form (human, required for submission)

In Play Console: **App content → Data safety**. Declare **no personal data is
collected**. This is accurate and must stay accurate:

- `TriageResult` carries no name / phone / NID.
- `CacheService` never persists symptom text (only the triage result +
  emergency contacts, 24 h TTL).
- No logging interceptor; no analytics SDK.
- Permissions used: `RECORD_AUDIO` (voice input), `ACCESS_FINE_LOCATION` /
  `ACCESS_COARSE_LOCATION` (nearby clinics), `INTERNET` (API). Each has a
  rationale prompt before first use.

## 5. Store listing copy (human)

Keep the internal-track description free of diagnosis or treatment claims. The
app is medical-adjacent and will be reviewed as one. The always-visible
disclaimer and the absence of dosage/antibiotic claims are the review
argument. Example-safe framing: "free Bangla-language AI health triage: tell
your symptoms, get an urgent-care level (home care / see a doctor / emergency)
and nearby hospitals." No percentages, no cures.

## 6. Physical device verification (human)

Install the §2 APK on a real device and check:

- [ ] Icon and splash render correctly across densities
- [ ] Voice input: mic works, rationale shows before the first prompt, typing
      works after denial
- [ ] TTS reads the result in Bangla
- [ ] Location: clinics list loads; deny → fallback Dhaka list + settings
- [ ] Dialling a hotline from the emergency sheet
- [ ] Light and dark theme
- [ ] Offline: cached triage result + hotlines render without network

## 7. Acceptance criteria map

| AC | Where |
|----|-------|
| Signed release build installs on physical device | §2 + §6 (human) |
| Voice / TTS / location / dialling work in release | §6 (human) |
| Icon and splash render across densities | committed assets + §6 |
| Uploaded to Play Console internal track | §3 (human) |
| Data Safety form: no personal data collected | §4 (human) |
| Listing has no diagnosis/treatment claims | §5 (human) |