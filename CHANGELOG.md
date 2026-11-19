# Changelog

## Unreleased

- **Fixed: moving a place to where you are could look like it did nothing.** Finding the phone's position can take up to 30 seconds and can fail indoors; Move pin → Use current position now says "Finding where you are…" while it waits, and if no position comes, says so and leaves the coordinates field ready. New Location no longer stays on "Finding where you are…" forever when no position comes: it offers Try again and Enter coordinates.
- **About → Open-source licences** lists every package Moment is built with, the typefaces (with the full SIL Open Font License text, now bundled as their licence asks), the Natural Earth map data and OpenStreetMap.
- The project has the files an open-source project should: a code of conduct, a support guide, issue forms for bugs and ideas (which ask for nothing from your journal), a pull request template, code owners, and Dependabot for the CI actions. `docs/ARCHITECTURE.md` maps the code for contributors.
- The site has an Open source section (how the promise is tested, how releases can be checked, how to help, credits) and a footer with every project link.

## 1.0.0-rc.1 — Release candidate for 1.0

Phase 5: no new kinds of log, but everything made sturdier, faster and
closer to the mockups, ready for 1.0 once it has been tried on phones.

- **Looks like the mockups.** Glass cards no longer look doubled: their
  shadow fell under the see-through card and showed through everywhere
  but a band along the top; it now falls outside, as designed. Photos,
  Videos and Locations are named in the plural, Library cards are the
  mockup's size, photo and video grids are headed by month, the Emoji
  section opens with This week, Audio is a list of recordings with their
  waveforms, and New photo and New video show a viewfinder frame and
  shutter (they still use the phone's own camera). Trash's Back button is
  round again.
- **Years of logs.** Home loads its feed a page at a time, Library counts
  each kind without reading every log, Calendar reads only the weeks it
  shows, and grids build only the rows on screen. Video posters in grids
  are decoded small. Tested with 20,000 logs, including a full back up
  and restore.
- **App lock.** Turning the lock on or off now takes effect at once:
  before, turning it off could leave a Lock screen with no PIN to unlock
  it until the app was restarted. After four wrong PINs each further try
  waits, from 30 seconds up to 15 minutes. While the lock is on, the app
  switcher shows no preview of the journal (on Android 12 and older this
  also blocks screenshots).
- **A lost key no longer strands you.** If the phone's secure storage
  loses the journal's key, Moment says so and offers to restore a backup
  or start an empty journal (after a second confirmation). The journal
  that cannot be opened is kept, never deleted.
- **Trash empties itself** of logs older than 30 days, files included, as
  it always said it would: that clean-up never actually ran before.
- **Diagnostics** (Settings → Diagnostics): a short log of errors and app
  events kept on the phone, never what you wrote, for you to read, copy
  or share. If Moment cannot start, it shows this instead of a blank
  screen.
- Every earlier version's database, backup and settings are tested to
  open in this one.
- Releases are checked before they are published: permissions exactly as
  listed, Android backup off, the encrypted SQLite inside every APK, the
  signing key, the version and the sizes.
- A privacy policy page on the site, and store text ready for when Moment
  is listed in a store.

Known limits: if no release key has been set up yet, this candidate is
signed with a throwaway key, so it does not install over 0.6.0: back up
in the app, uninstall, install, restore. The frame-rate check runs on an
emulator in CI; how scrolling feels is for a real phone to say.

## 0.6.0 — Home screen widget (Android)

- **Widget: Streak and Quick add.** One home screen widget with your
  streak on one side and a button for each kind of log on the other. A
  button opens that log's New screen; the streak opens the Streaks page.
  It comes in four sizes that follow how big you make it: 2 x 2, 4 x 1,
  4 x 2 and a small 2 x 1. Light and dark follow the phone, with the
  app's own colours. Android only for now; iOS comes later.
- **What it shows is your choice.** Settings → Widgets: "Streak and Quick
  add" (the default) or "Quick add only", which shows nothing from your
  journal. The widget never opens the encrypted journal. The app hands it
  a small snapshot (the streak, whether today is logged, this week's
  seven squares) and nothing else: no words, photos, places or emoji
  from your entries. Turning streaks off in the app also hides them on
  the widget.
- A widget is visible while Moment is locked. Tapping it goes through the
  lock first, then opens where you tapped. The Widgets screen says so.
- The widget stays right across midnight without the app running: the
  snapshot says how long the streak lasts, and the widget compares that
  with today. A streak at risk shows an outlined "Log today" pill, as on
  Home.
- **Add the widget** from Settings → Widgets (it asks the launcher), or by
  touching and holding the home screen.
- No new permission, no network. The snapshot stays on the phone, outside
  backups and cloud backup.

## 0.5.0 — Streaks

- **Streaks**: the number of days in a row you logged something, of any
  type. A day runs from midnight to midnight, in the time zone the log
  was made in, so a log at 23:50 stays on its day after travel. Streaks
  are worked out on the phone from your logs: nothing new is stored,
  backed up or sent, and a restored backup shows the right streak by
  itself. Logs in Trash do not count; backdating a log can fill a gap.
- **Home** has a flame chip beside Search with the count. It is a solid
  pill once you have logged today, an outlined pill with a small dot
  until then, and says Grace when yesterday was missed and forgiven. With
  no streak it is not shown.
- **Streaks page**, opened from the chip or from a card at the top of
  Calendar: the running streak and this week, the longest streak and
  totals, an Activity heatmap like a commit graph (a square a day, shaded
  by how many logs, for 3 months, 6 months or a year; tap or drag to read
  a day) and eight milestones (3, 7, 14, 30, 60, 100, 200 and 365 days)
  with the day each was reached. No pop-ups.
- **Calendar** shows the days of the running streak on a soft band.
- **Grace days**: Settings → Streaks forgives 0 to 3 missed days in any
  seven, so one bad day does not end a long streak. Forgiven days are
  outlined, count in the total and are never the first or last day of a
  streak. The default is 1. Streaks can also be switched off entirely.
- The evening reminder says nothing about streaks.
- **Accessibility**: the heatmap is one slider for a screen reader that
  steps a day at a time. Round header buttons (Back and the like) are now
  their own items for a screen reader instead of being read together with
  the title beside them.
- **Home** header: the weekday shrinks to fit beside the chip instead of
  overflowing at large text sizes.

## 0.4.4 — Fixes, a filter and no automatic backup

- **Library filter**: each card in the Library has a filter button. The
  popup chooses when (all time, today, last 7 or 30 days, this year),
  newest or oldest first, emoji strengths, and "only with a caption, a
  title or a name" for photos, videos, audio and places. The type's page
  shows what matches, says "Showing 3 of 12" and has Clear filter. Filters
  last until the app closes. The "Newest first" pill, which did nothing,
  is gone.
- **Audio**: when a recording ends the waveform now fills all the way. The
  saved length could run a little longer than the audio itself; the player
  now uses the length it finds in the file.
- **Quick emoji** on Home log at full strength (5).
- **Fewer notes**: the "stored on this device" and "search runs on this
  device" notes are gone from Home, Search, Lock, Photo, Location and New
  Location. About and Privacy still explain how the app treats your data.
  The photo's quality and storage bar is gone.
- **Your data stays in the app**: Android's automatic cloud backup and
  phone-to-phone transfer are switched off, so photos, videos, audio and
  the database are no longer copied to a Google account. The only way data
  leaves is a backup or export file you make. Keyboards are asked not to
  learn from what you type in the journal's fields.
- **Smaller downloads**: the release now comes as one APK per CPU type
  (arm64 for nearly every phone, about a third of the size) and a common
  one that works everywhere.
- **Updates**: releases are meant to install over the last one. This needs
  a one-time release key (`tool/make_release_key.sh`); the first release
  signed with it still needs one uninstall.

## 0.4.3 — Place maps and new players

- **Video player**, redesigned like the audio player: the picture with mute
  and fullscreen on it, a strip of frames to scrub along (a preview of the
  frame and its time follows your finger; the seek lands when you let go),
  play with Replay at the end, 15-second skips, loop and speed (1x, 1.25x,
  1.5x, 2x, 0.5x). Fullscreen turns the phone to suit the clip, hides its
  controls after three seconds, jumps 10 seconds on a double-tap of either
  half and pinches to zoom. The screen stays on while a video plays. The
  frames are made the first time you open a video and kept in the cache,
  never in a backup. "Stored on this device" is gone from this screen.

- **Audio player**, redesigned as a small music player: artwork card, a
  fine waveform you can drag (a time bubble follows your finger and the
  seek happens when you let go), big play and pause, 15-second skips,
  loop and a speed chip (1x, 1.25x, 1.5x, 2x, 0.75x). It works as one
  slider for screen readers. There is no text under the player: nothing
  is transcribed. A note written in an older version is kept in the
  database and backups but no longer shown on this screen.

- **Place maps**: a Location log now shows a small map of the place in
  the app's own colours, instead of a plain tile. It is drawn from Natural
  Earth data (public domain) bundled in the app, so nothing is fetched.
  Three zoom steps, Region, Area and City, with the width shown. The data
  has city outlines, main highways, rivers and state lines but no streets,
  so City (about 60 km across) is as close as it goes.

## 0.4.1 — Fixes

- **Photo and video**: Save shows progress on photos too, and a screen
  you leave while saving no longer tries to close itself afterwards.
  Errors while saving put Save back instead of leaving it spinning.
- **Audio**: when a recording ends the button changes from Pause back to
  Play, and Play starts it again from the beginning.
- The launcher icon is Moment's logo (checked at every Android density).

## 0.4.0 — Calendar, Search and Settings

Every screen in the mockups now exists, in light and dark.

- **Calendar**: a month at a time with a dot per type on each day. Tap a
  day to see its logs, filter by type, and jump back to today. Days are
  the ones logs were made on, so travel and daylight saving move nothing.
- **Search**: full-text search across text, emoji names, captions,
  titles, notes and place names, as you type. Results are grouped by type
  with the matched words highlighted; recent searches are kept on the
  device. It runs on the device (SQLite FTS5) and stays fast at 20,000
  logs. Logs in Trash are never found.
- **Settings** all work and apply at once: light, dark or system theme;
  Reduce Transparency; the five emoji of Home's quick row; an evening
  reminder (a local notification at a time you choose, which never shows
  anything from the journal); photo quality (original, 2560 px or
  1600 px; videos are always kept as recorded); and an About screen that
  says plainly how the app treats your data.
- **Dark theme**, designed for this release, and **Reduce Transparency**,
  which swaps glass for solid surfaces on every screen.
- **Smoother**: the app felt laggy because every card drew its own live
  blur of the background, a dozen or more per screen. Only the tab bar
  and small sheets blur now; cards are a translucent film over a
  background that is soft by itself and drawn once.
- **Accessibility**: every control has a label and a tap target of at
  least 44 pt, buttons can be pressed from a screen reader (many could
  only be announced before), and text fits at 200 % size.
- Fixed: the Search button on the Text, Emoji and Audio sections did
  nothing; Home's "How are you?" was cut short; the Privacy screen's Back
  button stretched across the screen.
- Upgrading from 0.3.0 keeps every log and makes all of them searchable.

Known limits: the APK is signed with a throwaway key until a release key
is set up (planned for 1.0.0), so it does not install over 0.3.0: back up
in the app, uninstall, install this one, then restore. Nothing in this
release has been tried on a physical phone by its author.

## 0.3.0 — Video and Location

The last two log types: all six can now be created, viewed, edited,
deleted, restored, exported and backed up.

- **Video**: record with the camera or choose a clip, add a caption. The
  clip is copied into app-private storage without being loaded into
  memory (tested with a 1 GB file), and a poster frame is made off the
  main thread. Grid section, and a player with scrubbing and 15-second
  skips.
- **Location**: pin where you are, or type coordinates; name the place and
  add a note. Access is explained before the system asks, and refusing,
  revoking or switching location off each say what to do instead.
  Coordinates are stored exactly and can be copied; the pin can be moved.
  The map is a stylised offline tile, not a real map.
- **Look up place names** (Privacy and backup, off by default): when you
  turn it on, a new pin's coordinates are sent to OpenStreetMap's
  Nominatim service and the name that comes back is offered for you to
  keep or replace. This is the only thing in the app that uses the
  internet, and with the switch off nothing can.
- **Backup, export, Trash and storage** cover all six types. Backups made
  by 0.2.0 still restore; a backup from a newer version is refused rather
  than half-read.
- Upgrading from 0.2.0 keeps every existing log.
- The Android build now declares the internet permission, for place names
  only. CI keeps network code to one file and one HTTPS host, and fails
  the release build on permissions a private journal never needs.
- Releases are tagged and published, APK attached, by a Release workflow.

Known limits: the new screens are simpler than the mockups (the system
camera rather than a custom viewfinder, no month headings in the video
grid); visual polish is Phase 5.

## 0.2.0 — Photo, Audio and Backup

Two more log types, and a way to take the whole library with you.

- **Photo**: take or choose a photo, add a caption; stored in app-private
  storage with location and other EXIF data stripped and a thumbnail made
  off the main thread. Grid section and full-screen detail.
- **Audio**: record a voice note with a live waveform, pause and resume;
  play it back with scrubbing and 15-second skips, and give it a title and
  a note.
- **Encrypted backup**: one passphrase-protected `.moment` file holding
  every log and media file, written and read in a stream so large
  libraries do not fill memory. A wrong passphrase or a damaged file is
  rejected without touching existing data, and restore is all or nothing.
- **Export**: a readable zip of Markdown, JSON and original files for the
  types you choose.
- **Storage by type** on the Privacy and backup screen.
- Upgrading from 0.1.0 keeps every existing log; deleting a photo or audio
  log removes its files once it leaves Trash.
- Still no internet permission in the release build, enforced by CI.

## 0.1.0 — Foundation, Text and Emoji

The first release: a completely local, encrypted life journal for two of
the six log types.

- **Security**: encrypted SQLite (SQLCipher) database, key held in Keychain
  or Keystore; no internet permission in the release build, enforced by CI.
- **App lock**: 4-digit PIN with Face ID, screen relocks whenever the app
  leaves the foreground.
- **Home**: a feed of Text and Emoji logs grouped by day, a one-tap mood
  row, and type filter chips.
- **Text and Emoji**: create (with backdating), view, edit, and delete to
  Trash, each in their own per-type section.
- **Library**: one tile per log type with its count and last-logged date.
- **Trash**: restore any deleted log, empty it with confirmation, or let it
  purge automatically after 30 days.
- **Settings**: the full hub screen, with Privacy (the app-lock part) and
  Trash wired up; other rows are placeholders for later phases.
- Design system: the glass-surface look, Inter and Newsreader type, and the
  decorative background throughout.
