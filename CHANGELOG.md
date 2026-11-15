# Changelog

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
