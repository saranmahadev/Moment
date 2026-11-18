#!/usr/bin/env bash
# Rebuilds test/fixtures/releases/<version>/ from each released version's
# own code: a database made by that version, and where the version had them,
# a backup and a settings file. Run from the repository root; needs Flutter
# and about ten minutes. The fixtures are committed, so this only needs
# running again to add a new release.
#
#   bash tool/fixtures/make_fixtures.sh [version ...]
set -euo pipefail

root="$(pwd)"
template="$root/tool/fixtures/generate_fixture_test.dart.tmpl"
work="${TMPDIR:-/tmp}/moment-fixtures"

# version  commit   features
releases=(
  "0.1.0 7b6d3ef"
  "0.2.0 957b9a3 MEDIA BACKUP"
  "0.3.0 c2b7b30 MEDIA BACKUP VIDEO SETTINGS"
  "0.4.0 26ecacb MEDIA BACKUP VIDEO SETTINGS THEMES"
  "0.5.0 2b7a928 MEDIA BACKUP VIDEO SETTINGS THEMES STREAKS"
  "0.6.0 54f4668 MEDIA BACKUP VIDEO SETTINGS THEMES STREAKS WIDGET"
)
all_tiers="MEDIA BACKUP VIDEO SETTINGS THEMES STREAKS WIDGET"

for line in "${releases[@]}"; do
  read -r version commit tiers <<<"$line"
  if [ $# -gt 0 ] && [[ " $* " != *" $version "* ]]; then continue; fi
  echo "== $version ($commit)"
  tree="$work/$version"
  rm -rf "$tree"; git worktree prune
  git worktree add --detach "$tree" "$commit" >/dev/null
  # Drop the parts of the generator this version has no code for.
  script="$(cat "$template")"
  for tier in $all_tiers; do
    if [[ " $tiers " != *" $tier "* ]]; then
      script="$(printf '%s\n' "$script" | sed "/^\/\/>$tier\$/,/^\/\/<$tier\$/d")"
    fi
  done
  printf '%s\n' "$script" > "$tree/test/generate_fixture_test.dart"
  out="$root/test/fixtures/releases/$version"
  rm -rf "$out"
  (
    cd "$tree"
    flutter pub get >/dev/null
    dart run build_runner build --delete-conflicting-outputs >/dev/null 2>&1
    TZ=Asia/Kolkata FIXTURE_OUT="$out" flutter test test/generate_fixture_test.dart
  )
  # The paths inside are this machine's; record where the phone root was so
  # tests can tell old absolute media paths apart.
  git worktree remove --force "$tree"
done
