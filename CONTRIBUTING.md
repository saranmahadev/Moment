# Contributing to Moment

Thank you for wanting to help. Moment is a small app with a strict promise (your journal stays on your phone), so the way changes are made matters as much as the changes.

## Before you start

- For anything larger than a small fix, open an issue first and say what you want to do. It saves both of us time.
- Read `docs/WORKFLOW.md` (how work is done) and `docs/ROADMAP.md` (what is planned, phase by phase).
- `CLAUDE.md` records every design decision made so far and why. If your change touches one, read that part.

## Setting up

You need Flutter 3.47.9 (the version CI uses).

```sh
git clone https://github.com/saranmahadev/Moment
cd Moment
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test --exclude-tags slow
```

## How a change is made

1. **One branch per change**, named for what it is: `feat/…`, `fix/…`, `test/…`, `docs/…`.
2. **Test first.** Commit a test that fails (`test: …`), then the change that makes it pass (`feat: …` or `fix: …`). A reviewer should be able to see the test fail before your change.
3. **Conventional Commits** for every message: `feat(search): …`, `fix(a11y): …`, `docs: …`.
4. **The gate** before a pull request, all three clean:
   ```sh
   dart format --set-exit-if-changed lib test tool
   flutter analyze
   flutter test
   ```
5. Do not commit generated `*.g.dart` files.

## Rules that protect the promise

These are enforced by tests, and a pull request that breaks one will not be merged:

- **No new network access.** The only code that may open a connection is the opt-in place-name lookup, in one file, to one address (`test/location/network_boundary_test.dart`). No analytics, crash reporting, ads or remote configuration, ever.
- **No new permissions** without a discussion first. The release build's permissions are listed and checked in CI.
- **Every device feature sits behind an interface** with a fake in `test/`, so it can be tested without a phone.
- **Colours come from the tokens** (`lib/design/tokens.dart`), never written into a screen, so both themes work.
- **No live blur on anything that scrolls or repeats.** It made the app lag once.
- **New screens join the every-screen checks** by being added to `test/support/screen_cases.dart`: light and dark baselines, labels, tap-target size, large text.
- **A new kind of log goes into backup before it appears in the app.**

## Design changes

Look at the mockup for a screen (`design/mockups/png/`) before changing it. To see every screen as it is now:

```sh
flutter test --run-skipped --tags preview test/gate/previews_test.dart   # writes build/previews/
```

If you change how something looks on purpose, regenerate the baselines and say so in the pull request:

```sh
flutter test --update-goldens test/gate/all_screens_test.dart --plain-name goldens
```

## Reporting problems

- **Bugs and ideas:** open an issue. Say what you did, what you expected and what happened, with the app version and your phone.
- **Security or privacy problems:** please do not open a public issue. See `SECURITY.md`.

## Licence

Moment is licensed under the GNU General Public License v3.0. By contributing, you agree that your contribution is licensed under the same terms.
