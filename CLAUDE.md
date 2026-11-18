# Moment: project context for Claude Code

Moment is a completely local life journal (Flutter + Drift on encrypted SQLite). Six SEPARATE log types, never merged: Text, Emoji, Photo, Video, Audio, Location. No cloud, no account, no analytics. One opt-in use of the internet: "Look up place names" (off by default; see the place-name decisions below).

Read `docs/WORKFLOW.md` first. It is the working agreement: strict TDD (a `test:` commit that fails, then a `feat:` commit that passes), one short-lived branch per chunk, `--no-ff` merges into `main`, Conventional Commits. Run `flutter test` before every commit. Do not commit generated `*.g.dart` files.

## Source of truth

Everything needed is in this repo, so no web access is required:

- `docs/ROADMAP.md`: the 5 phases with scope, tests to write first, exit gates and screen coverage. This is the plan to follow.
- `design/mockups/png/`: one reference image per screen (01 to 27, plus 00 App map and 28 Design language). Look at the image for a screen before building it.
- `design/mockups/*.dc.html`: the HTML source of each artboard. The inline styles hold exact radii, spacing, colours and glass recipes. See `design/README.md`.
- Original online copies (the owner can open these; they may not be reachable from here): plan https://claude.ai/artifact/U6uhFvGHSbxHXXBHjfF6uJ, roadmap https://claude.ai/artifact/BAyTndC6jNZxrHCFjKMS9i, mockups https://claude.ai/artifact/Svq4CmiaxtuNUS7KLV4JdH

Releases: Phase 1 = 0.1.0 (Foundation, Text and Emoji), 2 = 0.2.0 (Photo, Audio, Backup), 3 = 0.3.0 (Video, Location), 4 = 0.4.0 (Calendar, Search, Settings), 5 = 1.0.0 (polish and hardening). Tag `vX.Y.Z` only when CI is green and the phase exit gate is met.

## State

Phases 1 to 4 are released (`v0.3.0` and `v0.4.0` are published with their APKs; the owner decided not to tag 0.1.0 and 0.2.0 after the fact). 0.5.0 added Streaks (see the Streaks decisions); Phase 5 (1.0.0) is still ahead. Every screen in the mockups exists, in light and dark. `CHANGELOG.md` has the detail per release. Next is Phase 5 (polish and hardening, 1.0.0) in `docs/ROADMAP.md`; the owner wants the release signing key and other production setup done at the end of it. CI pins Flutter 3.47.9; develop and verify on that version. First time setup is in `README.md` (`flutter create` for platform folders, then `build_runner`).

Tags are never pushed by hand: the **Release** workflow (`.github/workflows/release.yml`, run with a version and optionally a commit) checks, builds, tags and publishes the APK in one go. See `docs/WORKFLOW.md`, "Releases".

## Phase 1 chunk order (each is a branch)

1. `feat/manifest-check`: `tool/check_manifest.dart` with a pure function `findForbiddenPermissions(String manifestXml)` (originally forbidding `android.permission.INTERNET`; see the place-name decisions for the current list), tests first in `test/tool/`. The script takes a file or directory and searches it recursively for `AndroidManifest.xml`. CI already calls it.
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

## Backup decisions (already made, Phase 2)

- One `.moment` file holds every log of every type, Trash included, plus every media file. Format v1 (`lib/backup/backup_cipher.dart`): a 48-byte header (magic `MOMENT\0\x01`, 16-byte salt, PBKDF2 iteration count, 20-byte nonce prefix) then XChaCha20-Poly1305 chunks of 256 KiB with the header, chunk index and a final flag bound as associated data. Key: PBKDF2-HMAC-SHA256, 150 000 iterations (tests inject fewer). Pure Dart via `package:cryptography`; no native crypto dependency.
- Inside: `BackupArchive`, the manifest (Drift row JSON per table, media paths relative to the app-support root) then each file in manifest order, SHA-256 checked while streaming. Export and restore stream in bounded memory.
- Restore is all or nothing: files land in a staging directory first, then move into place and rows are written in one transaction. Logs whose id already exists are skipped, so restoring twice is safe. A wrong passphrase is reported from the first chunk; anything after that is corruption; neither touches existing data.
- Device side behind `BackupFileGateway`: `share_plus` to hand the file over, `file_selector` to pick one. "Last backup" lives in `backup-state.json` in the support dir.
- Bump `BackupManifest.currentFormatVersion` (and keep reading older ones) when the archive changes; the format version in the header is for the container only. Manifest version 1 is 0.2.0 (text, emoji, photo, audio); version 2 adds `videoLogs` and `locationLogs` (0.3.0). An older app refuses a newer manifest rather than dropping what it does not know.
- Every new log type goes into backup before it is offered in the app (before it joins `builtLogTypes`).

## Video and Location decisions (already made, Phase 3)

- Schema version 4: `video_log` (log_id, path, poster_path, duration_ms, caption nullable) and `location_log` (log_id, latitude and longitude as REAL so they round-trip exactly, accuracy_m nullable, name nullable, note nullable). `LogRepository`: `createVideo`, `updateVideo`, `createLocation` (range-checked), `moveLocation`, `updateLocation`; `filesOf(log)` is the one list of files a log owns.
- Every device-facing package sits behind an interface with a fake in `test/`: `VideoPicker` (image_picker), `VideoProbe` (video_player for duration, fc_native_video_thumbnail for the poster), `VideoPlaybackController` (video_player), `LocationProvider` (geolocator, Android's own location manager rather than Play services). Do not use `video_thumbnail`: its Android build file no longer builds.
- Video files are copied by the operating system (`File.copy`) and streamed everywhere else; a 1 GB clip is imported and backed up with flat memory (`test/backup/backup_large_video_test.dart`, tagged `slow`; skip locally with `--exclude-tags slow`).
- Location never names a place by itself: `LocationProvider` has no geocoding. Naming is the separate, opt-in `PlaceNameLookup` (next section).
- Access is explained before the system is asked. States: granted, denied (can ask again), deniedForever (also covers revoked in Settings), serviceOff. Coordinates can always be typed instead; typed coordinates carry no accuracy.
- The map is `StylisedMap`, an offline tile; `projectPins` shows how places lie relative to each other, not where they are in the world.
- Platform declarations are tested (`test/platform/`): iOS usage descriptions for Face ID, microphone, camera, photo library and when-in-use location; Android fine and coarse location, never background.
- Golden baselines for the Phase 2 and 3 screens live in `test/goldens/`; `test/integration/shell_harness.dart` pumps the real `AppShell` with every seam faked.

## Place-name decisions (owner-approved, 0.3.0)

- The owner asked for the mockup's "Look up place names" toggle, knowing it needs the internet. So the rule is no longer "no internet permission" but "the internet for exactly one thing, off by default".
- `AppSettings` (`lib/settings/app_settings.dart`, JSON in `settings.json`, `AppSettings.inMemory()` in tests) holds `lookUpPlaceNames`, default false. `AppShell` hands `CreateLocationScreen` the lookup only while it is on; with it off the screen has nothing to call.
- `NominatimPlaceNameLookup` (`lib/location/nominatim_place_names.dart`) is the only file that may open a connection, and only to `https://nominatim.openstreetmap.org/reverse`. It sends coordinates rounded to five decimals, the language and `Moment/<version>`; no cookies or identifiers. It follows the service's usage policy: one request a second, never the same spot twice. Any failure is "no suggestion".
- A suggestion fills the name only if nothing was typed, and can be replaced. The Privacy screen says what is sent and to whom, with the OpenStreetMap credit.
- Guards: `test/location/network_boundary_test.dart` (one file, one host, HTTPS, no HTTP or geocoding packages, only `moment_app.dart` builds the real lookup), `test/integration/place_names_flow_test.dart` (off means never asked), `tool/check_manifest.dart` (prints every permission of the release manifest; forbids background location, advertising id, contacts, SMS, call log).
- `test/live/` talks to the real service and is skipped everywhere (`dart_test.yaml`, tag `live`) except the hand-run **Live check** workflow.
- `appVersion` in `lib/app/app_info.dart` must equal `pubspec.yaml` (tested); bump both at a release.

## Phase 4 decisions (Calendar, Search, Settings, dark mode)

- Settings live in `AppSettings` (see above): `themeMode`, `reduceTransparency`, `quickEmoji` (always five), `reminderOn` and `reminderTime`, `mediaQuality`, `recentSearches` (newest first, at most eight). Every setter notifies at once and then writes.
- Themes: `momentTheme({brightness, reduceTransparency})`; `MomentTokens.standard` (light, from the mockups) and `MomentTokens.dark` (designed in Phase 4, since the mockups are light only; released in 0.4.0). `ThemedApp` builds the `MaterialApp` from the settings. Screens never write a colour: `test/design/no_fixed_colours_test.dart` allows fixed colours only in the token file, the glass film and the video player. Use `tokens.onInk` on ink-filled controls and `tokens.scrim` for pills over media.
- Reduce Transparency is a flag on the tokens: `GlassSurface` then draws `solidSurface` with no `BackdropFilter`. `GlassSurface` is the only blur in the app.
- Performance (the owner reported lag): only `GlassVariant.strong` blurs (the dock, choice sheets); `card` and `surface` are a translucent film with no `BackdropFilter`, because each blur re-reads the screen every frame and a screen had a dozen. `OrbField` fades its orbs at the edge instead, uses no `Opacity` layer and sits in a `RepaintBoundary`. Tests: no screen case has a `BackdropFilter`, and the shell has exactly one (the dock). Do not add blur to anything that scrolls or repeats. Known and left for Phase 5: every tab keeps a live query of all logs (Library runs one per type just for a count).
- Calendar (`lib/calendar/`): `monthGrid` (six weeks from Monday, UTC midnights), `logsByDay` on `Log.localDay`, so travel and daylight saving move nothing; `summaryOf(log)` is the one-line description used by Calendar and Search.
- Search: schema version 5 adds an FTS5 table `log_search(log_id UNINDEXED, content)` with insert, update and delete triggers on each type table, created by `AppDatabase._createSearchIndex` (not a Drift table, so it is not in backups; restore fills it through the triggers). `rebuildSearchIndex()` refills it. `LogRepository.search` matches every typed word from its start, ignoring case and accents, never returns Trash, and is tested at 20,000 logs under 200 ms. `highlightParts` marks matches by the same rule.
- Reminder: `ReminderScheduler` seam over `flutter_local_notifications` (kept below 23, which needs Android compile SDK 37), inexact daily notification, rescheduled at each launch. The notification text says nothing from the journal.
- Photo quality: `MediaStore(photoQuality:)` scales the long edge to 2560 or 1600 px; videos are never re-encoded.
- Accessibility: a labelled button written as `Semantics(excludeSemantics: true, child: GestureDetector)` must also pass `onTap` to the `Semantics` (the exclusion hides the child's tap from screen readers); `test/gate/semantics_source_test.dart` enforces it. Fixed-shape layouts grow with the text size through `lib/design/text_growth.dart`.
- Every-screen checks: `test/support/screen_cases.dart` lists all 27 mockup screens plus About and the quick-emoji editor; `test/gate/all_screens_test.dart` runs each through Reduce Transparency (no blur, both themes), labels, 44 pt targets, text at 200 %, and light and dark goldens drawn with the app's real fonts. Add a new screen to that list.

## Place map decisions (owner-approved after a proof of concept, after 0.4.1)

- The Location preview is `PlaceMap` (`lib/location/place_map.dart`) over `lib/location/map/`: `MapWindow` (zoom, aspect, pin position, longitude scaled by cos(latitude)), `MapTile`/`MapScene` (decode and cull), `MapSource` (`AssetMapSource` reads `assets/map/`; tests use `FakeMapSource`), `MapPainter` (colours from the tokens, no fixed colours, no blur).
- Data: Natural Earth 1:10m (public domain), built by `tool/build_map_data.py` into 10 x 10 degree JSON tiles (`assets/map/<south>_<west>.json`, thousandths of a degree, delta-encoded). Regenerate with that script; the tiles are committed. About 15 MB raw, about 5.5 MB inside the APK.
- Zoom steps Region (about 460 km across), Area (170), City (60). No closer: the data has no streets. The span is always shown.
- Screens take an optional `mapSource`; without one they keep `StylisedMap` (all older tests). `AppShell` passes `AssetMapSource` from `moment_app.dart`. The Location section (many pins) still uses `StylisedMap`.
- Goldens for the Bengaluru proof-of-concept point (12.91227 N, 77.71650 E) are in `test/goldens/goldens/place_map_*`.
- Flow tests use a fixed clock: with the Ahem test font "Wednesday" overflows the Home header, so reading the real clock failed every Wednesday.

## Audio player decisions (owner-approved design, after 0.4.1)

- `AudioDetailScreen` is a music-style player: `_Artwork` card, `PlayerWaveform` (`lib/audio/player_waveform.dart`: 56 bars from `resamplePeaks`, glow at the playhead, drag to scrub with a time bubble, seek on release, one slider for TalkBack; no `LayoutBuilder` inside, because the screen sizes itself with `IntrinsicHeight`), play/pause, 15 s skips, Loop (`AudioPlaybackController.setLoop`) and a Speed chip cycling 1, 1.25, 1.5, 2, 0.75.
- The ended recording counts as stopped (`isAudibleState`), so the button shows Play and Play restarts it.
- No note under the player (nothing is transcribed). `AudioLog.note` stays in the schema and backups; the screen just does not show or edit it.
- No mini player, no background or lock-screen playback, no bookmarks, no clip sharing (owner declined).

## Video player decisions (owner-approved design, after 0.4.1)

- `VideoDetailScreen` (portrait) and `FullscreenVideoPlayer` share one `VideoPlayerModel` (position, playing, started, ended, mute, loop, speed 1/1.25/1.5/2/0.5; the screen that made the `VideoPlaybackController` still disposes it). Fakes: `FakeVideoPlaybackController`, `FakePlayerScreenControl`.
- `FrameStripScrubber` is the scrubber (frames, dimmed unplayed part, playhead, drag shows the nearest frame and its time, seek on release, one slider for TalkBack; no `LayoutBuilder` inside, same reason as `PlayerWaveform`).
- Frames: `VideoFrameStrip` makes 12 small JPEGs per video through `VideoProbe.writeFrame` (fc_native_video_thumbnail `at:`), into the app cache (`video-frames/<logId>/`), most recent 40 videos kept, never backed up, regenerated when missing.
- `PlayerScreenControl` (`DevicePlayerScreenControl`: SystemChrome fullscreen and orientation, `wakelock_plus` for keeping the screen on) sits behind an interface; wide clips go landscape, tall ones portrait.
- Controls over footage use two fixed colours in `lib/video/overlay_colours.dart` (a dark film, white marks); everything else comes from the tokens.
- A `VideoPlayerModel` or timer created in a `setUp` of a widget test runs on the wrong clock: create them inside the test.
- Not built (owner declined for now): mini player, picture-in-picture, background playback, captions.

## Streaks decisions (owner-approved design, 0.5.0)

- A streak is derived, never stored: `streakOf(days, today, grace:)` in `lib/streaks/streak_model.dart` is a pure function of the set of `Log.localDay` values (midnight to midnight in the zone the log was made in), so Trash, restore, backdating and backups need nothing. No schema or manifest change.
- Grace days (`AppSettings.graceDays`, 0 to 3, default 1; `showStreaks`, default on): a missed day does not break a streak while no more than `grace` days were missed in any seven in a row. A streak starts and ends on a logged day; today is not counted as missed until it is over. Forgiven days count in the total (a 12-day streak can be 11 logged plus 1 forgiven) and show as outlined squares.
- Data: `LogRepository.watchActiveDays()` and `watchDayCounts()` read one number per log with SQL (the day is `created_at_ms` plus the stored offset), not whole logs. `StreakBuilder` hands `StreakSummary?` to a screen (null while loading, with no settings, or when streaks are off).
- Screens: Home `StreakChip` (only when a streak exists), Calendar `StreakCard` (always, "Start a streak" when none, so the page stays reachable) and a band behind the running streak, `StreaksScreen` (hero and week, stats, Activity heatmap, milestones), `StreakSettingsScreen`, and a Streaks row in Settings. The evening reminder text is unchanged and never mentions streaks.
- The heatmap (`lib/streaks/heatmap_model.dart`, `streak_heatmap.dart`) is one painted surface, not hundreds of buttons: tap or drag picks a day, and a single slider is exposed to screen readers. A year is wider than the card and scrolls. Colours come from `MomentTokens.streakRamp` and `streakAccent`.
- Accessibility lesson: a labelled `Semantics` without `container: true` merges with its neighbours into one node (a Back button read together with the title; `find.bySemanticsLabel` then returns the whole row). Give separate controls `container: true`; `RoundGlassButton` now does.
- Design review page for the feature: https://claude.ai/artifact/Gz2G5sxJxSZaud9Q6bvCkz (not needed to build anything).

## Logo, site, film and open-source files (before Phase 5)

- Licence: GPL-3.0, chosen by the owner (`LICENSE`). `CONTRIBUTING.md` and `SECURITY.md` state the rules; the fonts' credits are in `assets/fonts/README.md`.
- Logo (`design/logo/`): one ink dot in a pane of glass, ringed by six dots in the type colours, over the app's orbs. `build_logo.py` writes the SVGs from the tokens and Newsreader; `export.cjs` renders the Android launcher icons (with adaptive layers), the iOS icon set and the site icons. `test/platform/app_icon_test.dart` checks every size.
- Site (`site/`, published to GitHub Pages by `.github/workflows/pages.yml`; the owner must set Pages' source to "GitHub Actions" once): one static page in the app's look. It loads nothing from other servers (`test/site/site_test.dart`): fonts, screens and the film are all in `site/`.
- Film (`design/video/`): a one-minute narrated film. `narration.json` is the script; `voice.py` speaks it with Kokoro (open TTS, run locally; a synthetic voice, said so on the site), then writes `timeline.js` (scene times from the length of each line), captions (`site/media/moment.vtt`) and the soundtrack (voice over a generated bed of chords, levelled to -16 LUFS). `moment.html` is the animation, timed per scene from `timeline.js`; `render.cjs` draws it frame by frame and encodes `site/media/` with ffmpeg. The narration was checked by transcribing it back with a speech-recognition model (every word matched); nobody has listened to it, so the voice and music are the owner's to judge. Screens for the site and the film are in `site/screens/`, copied from the preview renderer's output; refresh them when the app's look changes.
- When the version, the feature list or the privacy promise changes, update `README.md`, `site/index.html` and, if it shows it, the film.

## Visual language (for the design system chunk)

Minimal, frictionless glassmorphism. Newsreader for words, Inter for UI. Real blur only on floating surfaces (the tab bar and sheets; header buttons no longer blur, see the Phase 4 performance note). Feed cards use a translucent fill, gradient edge and soft shadow, because blur in scrolling lists janks on mid-range phones. Type colours: Text #1D4ED8, Emoji #B45309, Photo #BE185D, Video #6D28D9, Audio #0F766E, Location #15803D. Primary buttons ink #1B1F2A. Ground #EDF0F7. Tab bar: Home, Library, + (Add), Calendar, Settings. The mockups' source files are in the mockup artifact; goldens must match them.

## Open decisions (defaults until the owner says otherwise)

Minimum iOS 16 and Android 8 (API 26). Placeholder map, no real offline map. App lock is a screen gate (4-digit PIN plus Face ID). The dark palette was designed in Phase 4 and shipped in 0.4.0. Release signing is deferred to the end of Phase 5. No first-run backup explainer unless approved.
