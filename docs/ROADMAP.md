# Moment: Delivery Roadmap

Five phases, five releases: 0.1.0 to 0.4.0, then 1.0.0 with every screen in the mockups. Every phase is built test-first. Screens are numbered as in `design/mockups/png/` (01 to 27, plus 00 App map and 28 Design language).

| Phase | Release | Name | Exit gate |
| --- | --- | --- | --- |
| 1 | 0.1.0 | Foundation, Text and Emoji | Logs survive a restart; database unreadable without the key |
| 2 | 0.2.0 | Photo, Audio and Backup | A backup restores photos and audio on a fresh install |
| 3 | 0.3.0 | Video and Location | All six types created, viewed and backed up |
| 4 | 0.4.0 | Calendar, Search and Settings | All 27 screens exist and are reachable |
| 5 | 1.0.0 | Polish, hardening and release | Goldens match the mockups; release checks are green |

## How we build: test-first, every phase

No production code until a failing test asks for it: red, green, refactor.

**Test layers**

- Unit and repository tests on an in-memory Drift database cover the data rules for each log type.
- Encryption tests run against a real database file and prove it cannot be opened without the key.
- Widget tests cover every screen state shown in the mockups: empty, filled, error, locked.
- Golden tests compare each screen to an approved image. A baseline is approved only after it matches its artboard.
- Integration tests run one full flow per log type: create, view, edit, delete, restore.
- Release checks confirm the Android release manifest has no internet permission, and that backup and restore round-trips every type.
- Upgrade tests open a database from the previous release and check nothing is lost.

**Definition of done for any feature**

- Its acceptance test, taken from the mockup, passes.
- Golden images are approved against the artboard.
- Tap targets are at least 44 points and every control has a screen-reader label.
- Nothing touches the network.
- A new log type is included in backup, export, search and Trash.

**Routine for each phase**

1. Write the acceptance tests for the phase's screens and rules.
2. Implement until they pass.
3. Approve golden baselines against the mockups.
4. Test on a real iPhone and a real Android phone.
5. Tag the release and deliver it.
6. The owner tests it, fixes follow, and the next phase starts.

## Phase 1: Foundation, Text and Emoji (0.1.0)

**Screens:** 01 Lock, 02 Home, 03 Add, 04 Library, 05 New text, 06 New emoji, 11 Text section, 12 Emoji section, 17 Text detail, 18 Emoji detail, 25 Settings, 26 Privacy (lock part only), 27 Trash.

**Build**

- Flutter project, CI, lint rules, design tokens, bundled Inter and Newsreader fonts, icon set and the shared `GlassSurface` widget.
- Encrypted Drift database with numbered migrations. The key sits in Keychain or Keystore. Tables: `log`, `text_log`, `emoji_log`.
- App lock: PIN, Face ID, relock when the app goes to the background.
- Tab shell and Home feed with Text and Emoji cards, the one-tap mood row, and filter chips. The Add sheet shows only the types built so far.
- Text and Emoji: create, section list, detail, edit, backdate and delete to Trash.
- Library, Trash (restore and 30-day purge), the Settings hub, and the lock part of Privacy.

**Tests written first**

- Repository tests on an in-memory database: create, read, update and soft-delete for each type; day grouping across time zones; the 30-day purge removes rows.
- Encryption tests on a real file: unreadable by plain SQLite, wrong key fails, the key survives a restart.
- Widget tests for every card and screen state in the mockups: empty, typing, emoji selected, strength set, locked.
- Golden tests for Lock, Home, Add, New text, New emoji, Library and Trash, with baselines approved against the mockups.
- One integration test: create a text log, see it on Home, edit it, delete it, restore it.
- A script test that fails the build if the Android release manifest contains the internet permission.

**Exit gate**

- Every test above is green in CI.
- The owner reviews the Phase 1 screens against the mockups and approves them.
- Checked on one iPhone and one Android phone.
- 0.1.0 is tagged and delivered.

## Phase 2: Photo, Audio and Backup (0.2.0)

**Screens:** 07 New photo, 09 New audio, 13 Photo section, 15 Audio section, 19 Photo detail, 21 Audio detail, and 26 Privacy and backup completed.

**Build**

- Media pipeline: files copied into app-private storage under `media/YYYY/MM/`, thumbnails made off the main thread, GPS and other EXIF data stripped from photos.
- Photo: camera and gallery picker, caption, grid section, full-screen detail.
- Audio: recorder with live waveform, saved peaks, playback with scrubbing, title and transcript note.
- Backup: a single `.moment` file protected by a passphrase, streamed so large libraries don't fill memory. Restore into a fresh install.
- Export per type, and the storage-by-type screen.
- Tables added: `photo_log`, `audio_log`, with a migration from 0.1.0.

**Tests written first**

- Pipeline: the file is copied, the original is untouched, EXIF location is gone, thumbnails exist, deleting a log removes its files after the Trash period.
- Audio: peaks are stored and match the recording length; playback position survives a rotation.
- Backup round-trip: back up a library with text, emoji, photos and audio, restore on an empty database, and compare every row and file hash.
- Backup safety: wrong passphrase fails cleanly, a damaged file is rejected without touching existing data, restore is all or nothing.
- Upgrade: a 0.1.0 database opens in 0.2.0 with every log intact.
- Widget and golden tests for the six new screens and the finished Privacy screen.

**Exit gate**

- All tests green, including the 0.1.0 to 0.2.0 upgrade.
- A backup made on one phone restores photos and audio on a fresh install.
- The owner approves the six new screens against the mockups.
- 0.2.0 is tagged and delivered.

## Phase 3: Video and Location (0.3.0)

**Screens:** 08 New video, 10 New location, 14 Video section, 16 Location section, 20 Video detail, 22 Location detail. The Add sheet now offers all six types.

**Build**

- Video: record or pick, poster frame generated off the main thread, playback with controls, large files handled without loading them into memory.
- Location: drop a pin at the current position or search by coordinates, optional note, permission flow with a clear explanation, copy coordinates.
- Map area: a stylised offline tile as in the mockups. No map tiles are fetched, so the app stays fully local.
- Tables added: `video_log`, `location_log`, with a migration from 0.2.0.
- Backup, export, Trash and storage screens extended to cover both new types.

**Tests written first**

- Video: poster exists, duration is stored, a 1 GB sample is copied and backed up with memory staying flat, deleting removes file and poster.
- Location: coordinates round-trip exactly, permission denied and revoked states render the right message, no network call is made to name a place.
- Cross-type: one log of each of the six types survives backup and restore with the same content and timestamps.
- Upgrade: a 0.2.0 database opens in 0.3.0 intact.
- Widget and golden tests for the six new screens.

**Exit gate**

- All six types can be created, viewed, edited, deleted, restored and backed up.
- The owner approves the six new screens against the mockups.
- 0.3.0 is tagged and delivered.

## Phase 4: Calendar, Search and Settings (0.4.0)

**Screens:** 23 Calendar, 24 Search, and 25 Settings completed. After it, every screen in the mockups exists.

**Build**

- Calendar: month view with a dot per day coloured by type, tap a day to see its logs, jump to today.
- Search: full-text search across text, captions, titles and transcripts using SQLite FTS5, with type filters and recent searches. The index is kept up to date as logs change.
- Settings: reminders (local notifications only), light, dark and system themes, Reduce Transparency, quick emoji row, photo and video quality, About.
- Dark mode: designed at the start of the phase and approved before it is built, since the mockups are light only.
- Accessibility pass over every screen: large text, screen reader order, contrast, reduced motion.

**Tests written first**

- Calendar: day grouping is correct across time zones and daylight saving changes; a log made at 23:50 appears on the right day after travelling.
- Search: results match across all six types, deleted logs never appear, the index rebuilds correctly after restore, a library of 20,000 logs answers in under 200 ms.
- Settings: each option persists across restart and takes effect immediately; Reduce Transparency swaps blur for solid surfaces on every screen.
- Accessibility: every control has a label, tap targets pass the size check, text still fits at the largest system size.
- Goldens in light and dark for all 27 screens.
- Upgrade: a 0.3.0 database opens in 0.4.0 intact.

**Exit gate**

- Every one of the 27 screens exists and is reachable from the app map.
- The owner approves Calendar, Search, Settings and the dark theme.
- 0.4.0 is tagged and delivered.

## Phase 5: Polish, hardening and release (1.0.0)

No new screens. Phase 5 makes everything built so far match the mockups exactly, hold up under real use, and ship.

**Build**

- Fidelity pass: every screen compared to its artboard for spacing, type, colour, glass edge and shadow, with goldens tightened to a strict tolerance.
- Performance: scrolling stays smooth on a mid-range Android phone and an older iPhone. Real blur stays on floating surfaces only; feed cards use the cheaper translucent treatment.
- Security checks: the database is unreadable without the key, no network permission in the release build, backups excluded from iCloud and Google auto-backup, app-switcher preview hidden when locked.
- Scale: a library of 20,000 logs with thousands of photos opens fast and scrolls without jank.
- Upgrade path: databases from 0.1.0, 0.2.0, 0.3.0 and 0.4.0 all open correctly in 1.0.0.
- Local diagnostics log with no crash reporting service, so nothing leaves the phone.
- Store assets, privacy labels and release notes.

**Tests written first**

- A golden for each of the 27 screens, light and dark, at strict tolerance.
- Performance tests that fail the build if frame times regress on the reference devices.
- A full-library test: create, search, back up, restore and compare at scale.
- The complete upgrade matrix, plus a release checklist script that runs the security checks above.

**Exit gate**

- Every golden matches its mockup and every release check is green.
- The owner signs off a release candidate on their own devices.
- 1.0.0 is tagged and released with everything shown in the mockups.

## Screen coverage

| Phase | Release | New screens | Finished here |
| --- | --- | --- | --- |
| 1 | 0.1.0 | 13: Lock, Home, Add, Library, New text, New emoji, Text section, Emoji section, Text detail, Emoji detail, Settings, Privacy (lock part), Trash | |
| 2 | 0.2.0 | 6: New photo, New audio, Photo section, Audio section, Photo detail, Audio detail | Privacy and backup |
| 3 | 0.3.0 | 6: New video, New location, Video section, Location section, Video detail, Location detail | |
| 4 | 0.4.0 | 2: Calendar, Search | Settings, dark mode on all screens |
| 5 | 1.0.0 | None | Fidelity, performance, security, release |

Total: 13 + 6 + 6 + 2 = 27 screens, all in 1.0.0.

## Open decisions (defaults used until the owner says otherwise)

- Releases: Android APK; iPhone via TestFlight needs an Apple Developer account.
- Map: keep the stylised placeholder; a real offline map is not in 1.0.
- First-run backup explainer: not in the mockups; not built unless approved.
- Outside 1.0: home-screen widget, lock-screen shortcut, on-device transcription, import from other apps, any kind of sync.
- Dark mode: designed at the start of Phase 4.
- Minimum OS: iOS 16 and Android 8 (API 26).
- Security: app lock is a screen gate with the database key in Keychain or Keystore; media protected by app-private storage in 1.0.
