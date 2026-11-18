#!/usr/bin/env bash
# Makes Moment's release key, once, so every later release installs over the
# one before it instead of needing an uninstall.
#
#   bash tool/make_release_key.sh [folder]
#
# Run it on your own computer (needs the JDK's keytool and openssl). It
# writes moment-release.jks into [folder] (default: the current folder; do
# NOT put it inside the repository) and prints the four values to paste
# into GitHub: Settings > Secrets and variables > Actions > New repository
# secret. The key never goes in git. Keep a copy of the .jks and of the
# password somewhere safe (a password manager): if either is lost, the next
# release cannot update the installed app.
set -euo pipefail

folder="${1:-.}"
jks="$folder/moment-release.jks"
alias_name="moment"

command -v keytool >/dev/null || { echo "keytool not found: install a JDK (for example Temurin 17)." >&2; exit 1; }
command -v openssl >/dev/null || { echo "openssl not found." >&2; exit 1; }
if [ -e "$jks" ]; then
  echo "$jks already exists: refusing to overwrite a release key." >&2
  exit 1
fi
mkdir -p "$folder"

password="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"

keytool -genkeypair -v \
  -keystore "$jks" -alias "$alias_name" \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$password" -keypass "$password" \
  -dname "CN=Moment, O=Moment, C=IN" >/dev/null 2>&1
chmod 600 "$jks"

if base64 --help 2>&1 | grep -q -- '-w'; then
  encoded="$(base64 -w0 "$jks")"
else
  encoded="$(base64 -i "$jks" | tr -d '\n')"   # macOS
fi

cat <<OUT

Release key written to: $jks   (keep it safe; it is not in git)

Add these four secrets to the GitHub repository:

  ANDROID_KEYSTORE_PASSWORD   $password
  ANDROID_KEY_ALIAS           $alias_name
  ANDROID_KEY_PASSWORD        $password
  ANDROID_KEYSTORE_BASE64     (the long text in $jks.base64.txt)

OUT
printf '%s' "$encoded" > "$jks.base64.txt"
chmod 600 "$jks.base64.txt"

cat <<OUT
With the GitHub CLI (gh) signed in, these set them for you:

  gh secret set ANDROID_KEYSTORE_PASSWORD --body '$password'
  gh secret set ANDROID_KEY_ALIAS --body '$alias_name'
  gh secret set ANDROID_KEY_PASSWORD --body '$password'
  gh secret set ANDROID_KEYSTORE_BASE64 < '$jks.base64.txt'

Afterwards delete $jks.base64.txt (the .jks is the copy to keep).
The next release is signed with this key. Phones that have a release signed
with the old throwaway key must uninstall once (back up in the app first);
every release after that installs over the last one.
OUT
