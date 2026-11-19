# Security and privacy

Moment holds people's private journals, so problems here are taken seriously.

## Reporting a problem

Please report security or privacy problems privately, not in a public issue:

- On GitHub, open the repository's **Security** tab and choose **Report a vulnerability**. That sends a private report to the maintainers.

Say what you found, how to reproduce it, and which version you used. You will get a reply as soon as a maintainer has read it.

## What counts

- Anything that lets journal data leave the device without the owner choosing to send it.
- Any network connection other than the opt-in place-name lookup.
- A way past the app lock, or a way to read the database or a backup without the key or passphrase.
- A backup or restore that can lose or corrupt data.

## What Moment does to protect your data

- The database is encrypted (SQLite3MultipleCiphers) with a random key made on the device and kept in the Keychain or Keystore.
- Backups are encrypted with a passphrase only you know (PBKDF2-HMAC-SHA256, XChaCha20-Poly1305). Without the passphrase nobody can open one, including the maintainers.
- The app has no account, no analytics, no ads and no cloud. It uses the internet for one thing only, and only if you turn it on: "Look up place names" sends a new pin's coordinates to OpenStreetMap.
- Tests in the repository keep network code to one file and one address, and every release build is checked: the exact list of permissions, Android backup off, the encrypted SQLite inside each APK.
- While the app lock is on, the app switcher shows no preview of the journal, and wrong PINs make you wait longer each time.
- Diagnostics stay on the phone and never contain what you wrote.

## Supported versions

| Version | Fixes |
|---|---|
| 1.0.x (and the 1.0.0 release candidates) | Yes |
| 0.x | No: please update |

Only the newest release gets fixes. A fix is released as a new version, with the problem described in the changelog once people have had time to update.

## Checking a download

Every release lists the SHA-256 of each APK. Compare it with `sha256sum moment-<version>-arm64-v8a.apk` before installing a file you did not download from the releases page yourself.
