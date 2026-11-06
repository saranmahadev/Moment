# Moment

A completely local life journal. Six separate log types: Text, Emoji, Photo, Video, Audio and Location. No cloud, no account, no analytics, and no internet permission.

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
flutter analyze
dart format .
```

## Privacy checks

- `tool/check_manifest.dart` fails if a built Android manifest contains the internet permission. CI runs it on the release build.
- The database is encrypted with SQLite3MultipleCiphers. The key is random, created on first launch, and kept in the Keychain or Keystore.
