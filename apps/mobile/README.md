# Fidee Mobile

Flutter mobile app for Fidee social discovery.

## Development Setup

```powershell
cd D:\Project\mapvibe\apps\mobile
flutter pub get
flutter analyze
flutter test
```

## RevenueCat Development Mode

Fidee Pro uses RevenueCat Test Store during development. You do not need App Store Connect or Google Play Console accounts for this phase.

Configure SDK keys with `--dart-define`. The local `assets/env/mobile.env` file is ignored by git and is not bundled as a Flutter asset for release safety.

```text
REVENUECAT_IOS_API_KEY=<test-store-sdk-key>
REVENUECAT_ANDROID_API_KEY=<test-store-sdk-key>
GOONG_MAPTILES_KEY=<client-mobile-key>
GOONG_API_KEY=<client-mobile-key>
```

Product rules:

- Entitlement: `pro`
- Products: `fidee_pro_monthly`, `fidee_pro_yearly`
- RevenueCat App User ID: authenticated Cognito `sub`
- Purchase UI: custom Fidee bottom-sheet plan picker
- Backend sync endpoint: `POST /billing/revenuecat/sync`

The app should initialize RevenueCat after dotenv loads, log in with Cognito `sub` after auth, and sync the backend after purchase or restore. Offerings/paywall loading must not block the startup splash gate.

## Notes

- Customer Center is a phase-later Profile/Settings item, not part of development-mode MVP.
- Store production setup happens in Play Console and RevenueCat when Google developer accounts are ready.

## Google Play Release Checklist

Before uploading to CH Play / Google Play, complete the technical and policy checks below.

### 1. Upload Signing

Generate an upload keystore once and keep it outside git:

```powershell
cd D:\Project\mapvibe\apps\mobile\android
keytool -genkey -v -keystore app\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `apps/mobile/android/key.properties`:

```properties
storePassword=<keystore-password>
keyPassword=<key-password>
keyAlias=upload
storeFile=app/upload-keystore.jks
```

`key.properties` and keystore files are ignored by git. Release builds fail fast if this file is missing, so a Play upload cannot accidentally be signed with the debug key.

### 2. Production Defines

Do not bundle `assets/env/mobile.env` into Play builds. Pass client-safe production values at build time:

```powershell
cd D:\Project\mapvibe\apps\mobile
flutter build appbundle --release `
  --build-name 1.0.0 `
  --build-number 1 `
  --dart-define=GOONG_MAPTILES_KEY=<prod-goong-maptiles-key> `
  --dart-define=GOONG_API_KEY=<prod-goong-api-key> `
  --dart-define=GOONG_STYLE_URL=https://tiles.goong.io/assets/goong_map_web.json `
  --dart-define=REVENUECAT_ANDROID_API_KEY=<prod-revenuecat-android-sdk-key>
```

Increment `--build-number` for every Play upload. Use `--build-name` for the user-facing version.

### 3. Billing Setup

- Create Google Play subscription products matching `fidee_pro_monthly` and `fidee_pro_yearly`.
- Connect the Play app to RevenueCat and use the production Android SDK key.
- Confirm the backend accepts `PLAY_STORE` for `POST /billing/revenuecat/sync`.
- Test purchase and restore in Play internal testing before production rollout.

### 4. Permissions And Policy

- Location prompt is user-triggered from the in-app gate screen; disclose location collection in Data Safety and privacy policy.
- Camera and location hardware are marked optional so Play does not block unsupported devices unnecessarily.
- Photo permissions are still declared because gallery preview uses `photo_manager`; prepare the Play photo/media permission declaration or migrate to Android Photo Picker before launch.
- Provide app access instructions/test account in Play Console if reviewers cannot reach core screens without login.

### 5. Store Listing Readiness

- Publish a privacy policy URL and account deletion instructions.
- Complete Data Safety for location, photos/media, profile/account data, purchases, diagnostics/logs, and UGC if applicable.
- Document UGC moderation/report/block flows if users can upload or share public content.
- Configure Google OAuth SHA-1/SHA-256 for the Play upload/app-signing certificates.
