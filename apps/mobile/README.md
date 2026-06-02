# Fidee Mobile

Flutter app for the Fidee mobile client.

## SDK Setup

This app is pinned to:

- Flutter `3.41.9`
- Dart `3.11.5` through the bundled Flutter SDK

The pinned Flutter version lives in [`apps/mobile/.fvmrc`](./.fvmrc).

## Recommended Workflow

Use FVM so the whole team stays on the same Flutter/Dart SDK:

```bash
dart pub global activate fvm
cd apps/mobile
fvm use
fvm flutter pub get
fvm flutter run
```

If you open the repository in VS Code, the shared workspace setting at
`/.vscode/settings.json` points the Dart extension to `apps/mobile/.fvm/flutter_sdk`.
After `fvm use` creates that symlink, restart the Dart/Flutter analyzer if the IDE
does not switch automatically.

## Common Commands

```bash
cd apps/mobile
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run
```
