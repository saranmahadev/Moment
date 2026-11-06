# Moment: project context for Claude Code

Moment is a completely local life journal (Flutter + Drift on encrypted SQLite). Six SEPARATE log types, never merged: Text, Emoji, Photo, Video, Audio, Location. No cloud, no account, no analytics, no internet permission.

Read `docs/WORKFLOW.md` first. It is the working agreement: strict TDD (a `test:` commit that fails, then a `feat:` commit that passes), one short-lived branch per chunk, `--no-ff` merges into `main`, Conventional Commits. Run `flutter test` before every commit. Do not commit generated `*.g.dart` files.

## Source of truth

Everything needed is in this repo, so no web access is required:

- `docs/ROADMAP.md`: the 5 phases with scope, tests to write first, exit gates and screen coverage. This is the plan to follow.
- `design/mockups/png/`: one reference image per screen (01 to 27, plus 00 App map and 28 Design language). Look at the image for a screen before building it.
- `design/mockups/*.dc.html`: the HTML source of each artboard. The inline styles hold exact radii, spacing, colours and glass recipes. See `design/README.md`.
- Original online copies (the owner can open these; they may not be reachable from here): plan https://claude.ai/artifact/U6uhFvGHSbxHXXBHjfF6uJ, roadmap https://claude.ai/artifact/BAyTndC6jNZxrHCFjKMS9i, mockups https://claude.ai/artifact/Svq4CmiaxtuNUS7KLV4JdH

Releases: Phase 1 = 0.1.0 (Foundation, Text and Emoji), 2 = 0.2.0 (Photo, Audio, Backup), 3 = 0.3.0 (Video, Location), 4 = 0.4.0 (Calendar, Search, Settings), 5 = 1.0.0 (polish and hardening). Tag `vX.Y.Z` only when CI is green and the phase exit gate is met.

## State

Only the scaffold is committed. Nothing has been run yet: Flutter was not available where this was written, so all code written after this point should be verified by running it. First time setup is in `README.md` (`flutter create` for platform folders, then `build_runner`).

## Phase 1 chunk order (each is a branch)

1. `feat/manifest-check`: `tool/check_manifest.dart` with a pure function `findForbiddenPermissions(String manifestXml)` (forbidden: `android.permission.INTERNET`), tests first in `test/tool/`. The script takes a file or directory and searches it recursively for `AndroidManifest.xml`. CI already calls it.
2. `feat/data-layer`: Drift schema and repositories, tests first (see decisions below).
3. `feat/secure-database`: key store and encrypted opener, tests first.
4. `feat/design-system`: tokens (ThemeExtension), bundled Inter and Newsreader fonts, `GlassSurface`, golden tests against the artboards.
5. `feat/app-lock`, `feat/shell-and-home`, `feat/create-text`, `feat/create-emoji`, `feat/sections-and-details`, `feat/library`, `feat/trash`, `feat/settings-and-privacy-lock`.

Screens in Phase 1: Lock, Home, Add, Library, New text, New emoji, Text section, Emoji section, Text detail, Emoji detail, Settings, Privacy (lock part only), Trash.

## Data layer decisions (already made)

- Drift data classes are renamed (`@DataClassName('LogRow')`, `TextLogRow`, `EmojiLogRow`) so they do not clash with the domain classes `Log`, `TextLog`, `EmojiLog`.
- Tables: `log` (id UUID text PK, type text = `LogType.name`, `created_at_ms` int UTC epoch millis, `tz_offset_minutes` int, `edited_at_ms` nullable, `deleted_at_ms` nullable), `text_log` (log_id PK references log with cascade delete, body text), `emoji_log` (log_id PK references log with cascade delete, emoji text, label text nullable such as "Calm", strength int 1 to 5).
- Foreign keys on via `PRAGMA foreign_keys = ON` in `beforeOpen`.
- Times are stored as UTC epoch milliseconds plus the offset in minutes at creation, so a log made at 23:50 stays on its original local day after travel. The domain `Log.localDay` is `createdAt + offset`.
- `LogRepository` takes an injected clock and id generator. API: `createText`, `createEmoji`, `getById`, `watchFeed({types})` (not deleted, newest first, ties by id), `watchTrash`, `updateText`, `updateEmoji`, `setCreatedAt` (backdate), `softDelete`, `restore`, `purgeExpired(now)` (30 days), `deletePermanently`, `emptyTrash`. Validation: text must not be blank, emoji must not be empty, strength 1 to 5. Editing sets `edited_at_ms`.
- Feed uses one joined query (log left join text_log left join emoji_log) so the stream re-emits on any change.
- Repository tests run on an in-memory database: `AppDatabase(NativeDatabase.memory())`.

## Security decisions

- Key: 32 random bytes as 64 hex characters, created on first launch, held in Keychain or Keystore (`flutter_secure_storage`). Opened with `PRAGMA key = '<hex>'` in the `NativeDatabase` `setup` callback. Throw (not only assert) if `PRAGMA cipher;` returns nothing, so a release build without the cipher fails loudly.
- Tests: a real database file cannot be read by plain `sqlite3` without the key, a wrong key fails, the key survives a restart, generated keys are unique.
- Do not mix `sqlite3_flutter_libs` or `sqlcipher_flutter_libs` with the SQLite3MultipleCiphers hook in `pubspec.yaml`.

## Visual language (for the design system chunk)

Minimal, frictionless glassmorphism. Newsreader for words, Inter for UI. Real blur only on floating surfaces (tab bar, sheets, header buttons). Feed cards use a translucent fill, gradient edge and soft shadow, because blur in scrolling lists janks on mid-range phones. Type colours: Text #1D4ED8, Emoji #B45309, Photo #BE185D, Video #6D28D9, Audio #0F766E, Location #15803D. Primary buttons ink #1B1F2A. Ground #EDF0F7. Tab bar: Home, Library, + (Add), Calendar, Settings. The mockups' source files are in the mockup artifact; goldens must match them.

## Open decisions (defaults until the owner says otherwise)

Minimum iOS 16 and Android 8 (API 26). Placeholder map, no real offline map. App lock is a screen gate (4-digit PIN plus Face ID). Dark mode is designed at the start of Phase 4. No first-run backup explainer unless approved.
