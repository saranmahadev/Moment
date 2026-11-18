# Store listing

Text for an app store (Google Play, F-Droid) when Moment is published to one. 1.0 is released on GitHub only; this is ready for whichever comes next. Screenshots are in `screenshots/` (made by `test/gate/previews_test.dart`, phone size, light and dark).

## Name

Moment: private journal

## Short description (80 characters at most)

A private life journal: six kinds of log, encrypted on your phone, no account.

## Full description

Moment is a journal of your days that lives on your phone and nowhere else.

Log a moment the way it happened, in six kinds of log that are kept apart:

• Text: what happened, in your own words
• Emoji: how you felt, and how strongly
• Photo: what you saw, with a caption
• Video: how it moved
• Audio: a voice note
• Location: where you were, with a name and a note

Home shows today in one calm feed. The Library keeps a section for each kind, the Calendar shows a month at a glance, and Search finds anything you have written as you type. Streaks count the days in a row you log, with grace days you choose, and a home screen widget puts your streak and a button for each kind of log one tap away.

Private by how it is built:

• No account, no cloud, no analytics, no ads
• The journal is encrypted on your phone, with a key made on your phone
• An optional PIN lock, with fingerprint or face, and no app switcher preview while it is on
• Backups are one file, encrypted with a passphrase only you know, kept wherever you choose
• One switch can use the internet, and it is off: Look up place names asks OpenStreetMap to name a place you pin

Also: light and dark themes, Reduce Transparency, an evening reminder that never quotes your journal, export to Markdown and JSON, and Trash that keeps deleted logs for 30 days.

Moment is free and open source (GPL-3.0).

## Category and rating

- Category: Lifestyle (or Productivity)
- Content rating: Everyone. The app has no user-to-user features and no content from anyone but you.

## Privacy policy

https://saranmahadev.github.io/Moment/privacy.html (site/privacy.html)

## Google Play Data safety (if published there)

- **Data collected:** none. Nothing is sent to the developer or any third party by the app, except as below.
- **Data shared:** when the user turns on "Look up place names", approximate and precise location (the coordinates of a pin) is sent to OpenStreetMap's Nominatim service, at the user's request, to suggest a place name. Optional, off by default, not used for advertising or analytics, encrypted in transit (HTTPS).
- **Security practices:** data is encrypted in transit (the one request) and at rest (the journal). Users can delete their data in the app (Trash, Empty Trash; uninstalling removes everything).
- **Account:** none.

## Permissions, with reasons (as listed by `tool/release_check.dart`)

| Permission | Why |
|---|---|
| Location (fine, coarse) | Pin where you are, only while you do |
| Internet | Look up place names, only when turned on |
| Notifications, run at start-up, vibrate | The evening reminder |
| Biometric, fingerprint | The app lock |
| Record audio | Audio logs |
| Network state, wake lock | Added by the share sheet and video player plugins |
