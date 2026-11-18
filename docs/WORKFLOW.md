# Working agreement: TDD and git

## Branches

- `main` always builds and passes every test. Nothing is committed to it directly except merges.
- One short-lived branch per chunk of work: `feat/<topic>`, `fix/<topic>`, `chore/<topic>`.
- A chunk is a slice a person can review in one sitting: one rule, one screen, one pipeline.
- A chunk merges into `main` with `git merge --no-ff`, so every chunk stays visible in history as one unit.

## TDD inside a chunk

Each behaviour is two commits, in this order:

1. `test(<scope>): <behaviour>` : the failing test (red).
2. `feat(<scope>): <behaviour>` : the least code that makes it pass (green). Refactors get their own `refactor:` commit and never change behaviour.

Small related behaviours can share one red/green pair. Production code never lands without a test commit before it.

## Commit messages

Conventional Commits: `type(scope): summary` in the imperative, 72 characters or fewer, with a body saying why when it is not obvious.
Types: `feat`, `fix`, `test`, `refactor`, `chore`, `docs`, `ci`, `build`.

## Merge gate

Before a chunk merges into `main`:

- `dart format --set-exit-if-changed .` is clean.
- `flutter analyze` has no issues.
- `flutter test` is green.
- For UI chunks, golden images are approved against the mockup artboard.

## Releases

- Each phase ends with a tag `v0.1.0`, `v0.2.0`, `v0.3.0`, `v0.4.0`, and `v1.0.0` after Phase 5.
- A tag is created only after CI is green on the release commit and the phase exit gate in the roadmap is met.
- `CHANGELOG.md` gets one entry per release.
- Tags are made by the **Release** workflow (`.github/workflows/release.yml`), never by hand: Actions → Release → Run workflow, with the version (and the commit, when it is not the head of `main`). In one run it checks the version against `pubspec.yaml` and the changelog, analyses, tests, builds the release APKs (one per CPU type, and a common one that works on every phone but is about three times larger), checks the permissions of the release manifest, creates the annotated tag and publishes a GitHub Release with all of them attached: `moment-X.Y.Z-arm64-v8a.apk` (nearly every phone), `-armeabi-v7a` (old 32-bit phones), `-x86_64` (emulators) and `moment-X.Y.Z.apk` (common). If any step fails, nothing is tagged.
- Releasing an older commit (not the head of `main`): GitHub does not let a workflow tag a commit whose workflow files differ from `main`'s. Push that tag by hand (`git tag -a v0.1.0 <commit> -m "Moment 0.1.0" && git push origin v0.1.0`), then run the Release workflow with the same version and commit: it sees the tag, and builds and publishes the release for it.
- `release-check.yml` builds the same APKs without releasing them; it runs automatically when dependencies or the `android/` project change.

### Signing the APK

Android only installs an update over an app signed with the same key. Until a release key is configured, the Release workflow signs with a throwaway debug key that is different on every run, so a new release will not install over the old one (back up in the app, uninstall, install, restore).

To fix that once, create a key and give it to the repository as secrets (Settings → Secrets and variables → Actions). The key itself never goes in git; keep a copy somewhere safe, because losing it means no more in-place updates.

```
keytool -genkeypair -v -keystore moment-release.jks -alias moment \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 moment-release.jks   # macOS: base64 -i moment-release.jks
```

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the base64 text printed above |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password you chose |
| `ANDROID_KEY_ALIAS` | `moment` |
| `ANDROID_KEY_PASSWORD` | the key password (leave unset if it is the same as the keystore's) |

## Never in git

Signing keys, `key.properties`, user data, generated `*.g.dart` files.
