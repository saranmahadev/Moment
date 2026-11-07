# Changelog

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
