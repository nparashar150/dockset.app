#!/usr/bin/env bash
#
# Photographs the app's real detail panels for the README.
#
# Builds the Shots target, which puts each panel in a real window on a real
# display and prints where it landed; this script then screenshots that region.
# The round trip exists because the panels' surface is a behind-window
# NSVisualEffectView: it has nothing to sample unless the window is genuinely
# on screen, so an offscreen render is not the same picture.
#
# Must be run on a Mac, sitting at a real display that is awake and unlocked.
# Screen Recording permission belongs to whatever runs this — Terminal, iTerm,
# your editor — not to the Shots binary, so the first run may capture blank
# images until that app is ticked in System Settings > Privacy & Security >
# Screen & System Audio Recording, and restarted.
#
# The run takes a couple of minutes: one panel draws a live graph from a
# rolling one-second sampler, and the script waits for that minute rather than
# shipping a graph with four points in it. The panels sit above everything else
# on the display while they are captured, so leave the machine alone until it
# prints its summary.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/docs/images"
DERIVED="${TMPDIR:-/tmp}/plinth-shots-build"

fail() { printf 'capture-shots: %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "macOS only — this drives the window server."
[ -z "${SSH_CONNECTION:-}" ] || fail "run this at the Mac itself; an SSH session has no display to capture."
command -v xcodebuild >/dev/null || fail "xcodebuild not found — install the Xcode command line tools."
command -v screencapture >/dev/null || fail "screencapture not found."

echo "capture-shots: building the Shots target…"
# -target rather than -scheme, so this does not depend on a generated scheme —
# but xcodebuild refuses -derivedDataPath without one, so the build lands in the
# project's usual location and the binary is found by asking where that is.
xcodebuild -project "$ROOT/Plinth.xcodeproj" \
           -target Shots \
           -configuration Release \
           build >"$DERIVED.log" 2>&1 \
  || { tail -40 "$DERIVED.log" >&2; fail "build failed; the full log is at $DERIVED.log"; }

PRODUCTS=$(xcodebuild -project "$ROOT/Plinth.xcodeproj" -target Shots \
                      -configuration Release -showBuildSettings 2>/dev/null \
           | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')
BIN="$PRODUCTS/Shots"
[ -x "$BIN" ] || fail "built, but no executable at $BIN"

mkdir -p "$OUT_DIR"

# Two named pipes rather than a sleep: the tool prints a frame, waits, and only
# tears the window down once this script says the capture came back. A fixed
# wait is either too short on a busy machine or wasted on an idle one, and a
# capture that lands early is silently half a window.
PIPES="$(mktemp -d "${TMPDIR:-/tmp}/plinth-shots.XXXXXX")"
FRAMES="$PIPES/frames"
ACK="$PIPES/ack"
mkfifo "$FRAMES" "$ACK"

SHOTS_PID=""
cleanup() {
  [ -n "$SHOTS_PID" ] && kill "$SHOTS_PID" 2>/dev/null || true
  rm -rf "$PIPES"
}
trap cleanup EXIT

# Opened read-write so the tool's stdin never sees EOF between acknowledgements.
exec 3<>"$ACK"
"$BIN" <&3 >"$FRAMES" &
SHOTS_PID=$!
exec 4<"$FRAMES"

WRITTEN=()
FAILED=()

while read -r name x y w h <&4; do
  dest="$OUT_DIR/$name.png"
  rm -f "$dest"
  screencapture -x -R "$x,$y,$w,$h" "$dest" || true
  printf 'ok\n' >&3

  if [ -s "$dest" ]; then
    WRITTEN+=("$name")
    printf 'capture-shots: %-16s %sx%s pt\n' "$name" "$w" "$h"
  else
    FAILED+=("$name")
    printf 'capture-shots: %-16s NO IMAGE\n' "$name" >&2
  fi
done

wait "$SHOTS_PID" || fail "the Shots tool exited badly; nothing further was captured."
SHOTS_PID=""

echo
echo "capture-shots: wrote ${#WRITTEN[@]} image(s) to docs/images/"
for name in "${WRITTEN[@]:-}"; do
  [ -n "$name" ] || continue
  # `|| true`: a file sips cannot read reports no size rather than taking the
  # whole summary down with it — the check that matters already ran above.
  pw=""; ph=""
  read -r pw ph < <(sips -g pixelWidth -g pixelHeight "$OUT_DIR/$name.png" 2>/dev/null \
                    | awk '$1=="pixelWidth:"{w=$2} $1=="pixelHeight:"{h=$2}
                           END{if (w ~ /^[0-9]+$/ && h ~ /^[0-9]+$/) print w, h}') || true
  printf '  docs/images/%-22s %sx%s px\n' "$name.png" "${pw:-?}" "${ph:-?}"
done

if [ "${#FAILED[@]}" -gt 0 ] && [ -n "${FAILED[0]:-}" ]; then
  echo
  printf 'capture-shots: %s capture(s) produced nothing: %s\n' "${#FAILED[@]}" "${FAILED[*]}" >&2
  echo "capture-shots: a blank or missing file almost always means Screen Recording" >&2
  echo "               permission is missing for the app running this script." >&2
  exit 1
fi

if [ "${#WRITTEN[@]}" -eq 0 ]; then
  fail "the tool printed no frames at all; check $DERIVED.log and that a display is awake."
fi
