#!/usr/bin/env bash
#
# Regenerates Docket's app icon from source.
#
# The icon is not a file someone once exported - it is geometry in
# Tools/Icon/make-icon.swift. Tweak a number there, run this, and every PNG in
# Resources/Assets.xcassets/AppIcon.appiconset plus its Contents.json is rewritten
# together, so the catalog can never drift from the drawing.
#
# Takes a couple of seconds. Needs nothing but a Mac with the Swift toolchain.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/Tools/Icon/make-icon.swift"
OUT="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset"

fail() { printf 'make-icon: %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "macOS only - the generator draws with CoreGraphics."
command -v swift >/dev/null || fail "swift not found - install the Xcode command line tools."
[ -f "$SRC" ] || fail "no generator at $SRC"

echo "make-icon: drawing…"
swift "$SRC" "$OUT"

echo
echo "make-icon: verifying what landed in Resources/Assets.xcassets/AppIcon.appiconset/"
BAD=0
for png in "$OUT"/*.png; do
  name="$(basename "$png")"
  # icon_128x128@2x.png claims 128 pt at 2x, i.e. 256 px. The filename is the
  # contract Xcode reads, so it is checked against the actual pixels rather
  # than trusted.
  pts="${name#icon_}"; pts="${pts%%x*}"
  scale=1; case "$name" in *@2x.png) scale=2 ;; esac
  want=$((pts * scale))

  read -r got_w got_h < <(sips -g pixelWidth -g pixelHeight "$png" 2>/dev/null \
                          | awk '$1=="pixelWidth:"{w=$2} $1=="pixelHeight:"{h=$2} END{print w, h}')

  if [ ! -s "$png" ]; then
    printf '  %-22s EMPTY FILE\n' "$name" >&2; BAD=$((BAD + 1))
  elif [ "$got_w" != "$want" ] || [ "$got_h" != "$want" ]; then
    printf '  %-22s %sx%s px - expected %sx%s\n' "$name" "$got_w" "$got_h" "$want" "$want" >&2
    BAD=$((BAD + 1))
  else
    printf '  %-22s %sx%s px  %s bytes\n' "$name" "$got_w" "$got_h" "$(stat -f%z "$png")"
  fi
done

# A Contents.json that does not parse fails the build with a message that points
# nowhere near the real problem, so it is checked here where the cause is obvious.
# `-convert` rather than `-lint`: plutil's linter refuses JSON outright, while
# converting it to a plist and throwing the result away parses it for real.
for json in "$OUT/Contents.json" "$(dirname "$OUT")/Contents.json"; do
  plutil -convert xml1 -o /dev/null "$json" >/dev/null 2>&1 || fail "malformed JSON: $json"
done
echo "  Contents.json          valid (icon set and catalog root)"

[ "$BAD" -eq 0 ] || fail "$BAD file(s) are wrong - the catalog is not safe to build against."

echo
echo "make-icon: done. project.yml needs ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon"
echo "           and Resources/Assets.xcassets listed in the app target's sources."
