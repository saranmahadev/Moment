# Changelog

## Unreleased

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
