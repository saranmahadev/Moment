# How Moment is built

A map of the code for anyone about to change it. The why behind each decision is in `CLAUDE.md`; the plan is in `docs/ROADMAP.md`; how work is done is in `docs/WORKFLOW.md`.

## In one picture

```
 main.dart ─ diagnostics, licences
     │
 MomentApp ── JournalOpener ── encrypted SQLite (SQLite3 Multiple Ciphers)
     │              │                 key in Keystore / Keychain
     │        JournalProblemScreen (lost key)
     │
 LockGate ── AppLockController ── PIN hash in secure storage
     │
 AppShell ── Home · Library · Calendar · Settings tabs, Add sheet
     │
 screens ──► LogRepository ──► Drift (AppDatabase)
         ──► MediaStore (photos, audio, video files in app-private storage)
         ──► seams: pickers, recorder, players, location, place names,
                    reminders, backup files, widget bridge, screen privacy
```

Everything a screen shows comes from `LogRepository` streams. Everything a screen does to the outside world goes through an interface (a "seam") with a real implementation in `lib/` and a fake in `test/`.

## Layers

| Layer | Where | What it owns |
|---|---|---|
| Domain | `lib/domain/` | The six kinds of log (`TextLog`, `EmojiLog`, `PhotoLog`, `VideoLog`, `AudioLog`, `LocationLog`), sealed under `Log`. A log's day is `localDay`: its time plus the offset it was made in, so travel never moves it. |
| Data | `lib/data/` | `AppDatabase` (Drift tables, migrations, the full-text search index and feed indexes), `LogRepository` (the only way screens read and write logs), `MediaStore` (importing files, stripping photo metadata), `JournalOpener` and `KeyStore` (the encryption key). |
| Design | `lib/design/` | `MomentTokens` (every colour, light and dark), `GlassSurface` (the glass recipes; the only blur), `OrbField`, shared controls. Screens never write a colour. |
| Screens | `lib/home/`, `lib/library/`, `lib/section/`, `lib/calendar/`, `lib/search/`, `lib/streaks/`, `lib/settings/`, `lib/privacy/`, `lib/trash/` | What people see. Each takes its dependencies in its constructor. |
| Kinds | `lib/text/`, `lib/emoji/`, `lib/photo/`, `lib/video/`, `lib/audio/`, `lib/location/`, `lib/detail/` | Creating and viewing each kind of log. |
| Backup and export | `lib/backup/`, `lib/export/` | The encrypted `.moment` format (streamed, chunked XChaCha20-Poly1305), restore (all or nothing), and readable exports. |
| App | `lib/app/`, `lib/shell/` | Start-up, the lock gate, the shell with its tabs and navigation, deep links from the widget. |
| Platform | `android/app/src/main/kotlin/` | `MainActivity` (widget and screen-privacy channels) and the home screen widget. |

## Rules the code keeps

These are enforced by tests, so breaking one fails CI.

- **One way out to the network.** Only `lib/location/nominatim_place_names.dart` may open a connection, to one HTTPS address, and only while "Look up place names" is on (`test/location/network_boundary_test.dart`).
- **Permissions are a list, not an accident.** `tool/release_check.dart` holds the exact list, each with its reason, and checks the built APK.
- **Six kinds stay six.** Every kind has its own table, screens and backup section. A new kind goes into backup before it appears in the app.
- **No full reads to show a little.** A screen asks for a page, a date window or a count (`watchFeed(limit:)`, `watchFeedBetween`, `watchTypeSummaries`), never every log.
- **Nothing private in logs.** `DiagnosticsLog` keeps error types and code locations, never messages.
- **Colours from tokens; blur only where it floats.** `test/design/no_fixed_colours_test.dart` and the every-screen checks.

## Tests

| Where | What |
|---|---|
| `test/<area>/` | Unit and widget tests, mirroring `lib/`. Repositories run on an in-memory database. |
| `test/gate/` | Every screen (`test/support/screen_cases.dart`) through labels, 44 pt targets, 200 % text, Reduce Transparency and light and dark baselines. |
| `test/integration/` | The real shell with every seam faked (`shell_harness.dart`), driven through whole flows. |
| `test/upgrade/` | Databases, backups and settings made by every released version, opened by this one. |
| `test/scale/` | 20,000 logs: screens stay lazy; a full back up and restore compares every row and file (tagged `slow`). |
| `integration_test/` | Scrolling on an Android emulator, measured frame by frame (the Frame budget workflow). |
| `android/app/src/test/` | The widget's Kotlin model, on the JVM. |

## Releases

The **Release** workflow checks the version, runs every test, builds the APKs, runs `tool/release_check.dart` on them, then tags and publishes. Versions like `1.0.0-rc.1` are published as pre-releases. See `docs/WORKFLOW.md`.
