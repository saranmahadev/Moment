# Changelog

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
