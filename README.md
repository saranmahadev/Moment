# Moment

A completely local life journal. Six separate log types: Text, Emoji, Photo, Video, Audio and Location. No cloud, no account, no analytics. The app uses the internet for one thing only, and only if you turn it on: "Look up place names" (off by default) sends a new pin's coordinates to OpenStreetMap to suggest a name.

Built in five phases, one release each: 0.1.0, 0.2.0, 0.3.0, 0.4.0, then 1.0.0. Every phase is built test-first. See `docs/WORKFLOW.md` for the git and TDD rules.

## First-time setup

```sh
# Once, to create the android/ and ios/ folders, then commit them:
flutter create . --platforms=android,ios --project-name moment --org app.moment

flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Everyday commands

```sh
dart run build_runner watch --delete-conflicting-outputs   # regenerate Drift code
flutter test                                                # all tests
flutter test --exclude-tags slow                            # skip the 1 GB video test
flutter analyze
dart format .

# Regenerate the light and dark baselines of every screen after a deliberate change
flutter test --update-goldens test/gate/all_screens_test.dart --plain-name goldens

# Write every screen to build/previews/ as PNG (light, dark, glass, solid) to look at
flutter test --run-skipped --tags preview test/gate/previews_test.dart
```

## Checks on every screen

`test/support/screen_cases.dart` lists every screen of the app. `test/gate/all_screens_test.dart` runs each one through the same checks: Reduce Transparency leaves no blur in either theme, every control has a label and a 44 pt tap target, text fits at 200 % size, and it matches its light and dark baseline. A new screen joins all of them by being added to that list.

## Releasing

Run the **Release** workflow (Actions → Release → Run workflow) with the version. It checks, builds, tags and publishes the APK in one go. See `docs/WORKFLOW.md`, "Releases", including how to set up the signing key so updates install over each other.

## Privacy checks

- `test/location/network_boundary_test.dart` keeps network code to one file (the opt-in place-name lookup, one host, HTTPS) and keeps HTTP and geocoding packages out of the dependencies. With the setting off, the app is never even handed the lookup.
- `tool/check_manifest.dart` lists every permission the built Android manifest asks for and fails on ones a private journal never needs (background location, advertising id, contacts, SMS, call log). CI runs it on the release build.
- The **Live check** workflow (run by hand) asks the real place-name service two questions, to confirm the request the app sends still works.
- The database is encrypted with SQLite3MultipleCiphers. The key is random, created on first launch, and kept in the Keychain or Keystore.
