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

Configure SDK keys with either `assets/env/mobile.env` or `--dart-define`:

```text
REVENUECAT_IOS_API_KEY=<test-store-sdk-key>
REVENUECAT_ANDROID_API_KEY=<test-store-sdk-key>
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
- Store production setup happens later when Apple/Google developer accounts are ready.
