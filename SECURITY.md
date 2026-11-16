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
- Tests in the repository keep network code to one file and one address, and CI lists every permission the release build asks for.

## Supported versions

Until 1.0, only the latest release gets fixes.
