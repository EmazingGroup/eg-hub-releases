#!/bin/bash
# EG Hub: one-command install for an Emazing Group teammate's Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/EmazingGroup/eg-hub-releases/main/install.sh | bash
#
# Public on purpose, like everything else in this repo: nothing here is secret,
# and the app does nothing without a work Google account on an allowed domain.
#
# What it does, in order:
#   1. Refuses anything that is not an Apple-chip Mac (no Intel build exists).
#   2. Reads the same update feed the app itself reads (updates/latest-stable.json,
#      or latest-test.json with EGHUB_RING=test), so a fresh install is exactly
#      the build its own updater expects. No hard-coded version.
#   3. Downloads that build, checks it is signed by Emazing Group (Apple team
#      FQJPY8W5U6) before putting it anywhere.
#   4. Installs to /Applications, or ~/Applications if this account cannot write
#      there (no admin password prompt either way), and opens it.
#
# Run it again any time to reinstall the current build. To remove EG Hub, drag it
# from Applications to the Trash.
set -euo pipefail
# A Terminal with a trimmed PATH must still find sysctl, codesign and ditto
# (found in testing: without /usr/sbin the chip check read an M-series Mac as Intel).
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

RING="${EGHUB_RING:-stable}"
FEED="https://raw.githubusercontent.com/EmazingGroup/eg-hub-releases/main/updates/latest-${RING}.json"
TEAM_ID="FQJPY8W5U6"
APP="EG Hub.app"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nSTOPPED: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "EG Hub is a Mac app."
# hw.optional.arm64 is 1 on an Apple chip even when this shell runs under Rosetta.
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] \
  || die "EG Hub needs a Mac with an Apple chip (M1 or newer). This Mac has an Intel chip, so it can't run EG Hub yet. Ask in #eg-hub-testing."

WORK="$(mktemp -d /tmp/eg-hub-install.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

say "Finding the current EG Hub build"
curl -fsSL "$FEED" -o "$WORK/feed.json" || die "couldn't reach GitHub. Check your internet connection and run this again."
VERSION="$(plutil -extract version raw -o - "$WORK/feed.json")"
URL="$(plutil -extract platforms.darwin-aarch64.url raw -o - "$WORK/feed.json")"
[ -n "$URL" ] || die "the update feed has no Mac build listed. Ask in #eg-hub-testing."

say "Downloading EG Hub $VERSION"
curl -fL --progress-bar "$URL" -o "$WORK/eghub.tar.gz" || die "download failed. Run this again."
tar -xzf "$WORK/eghub.tar.gz" -C "$WORK"
[ -d "$WORK/$APP" ] || die "the download didn't contain $APP."

say "Checking it is signed by Emazing Group"
codesign --verify --deep --strict "$WORK/$APP" 2>/dev/null || die "signature check failed, so nothing was installed."
# Capture, then match: `codesign | grep -q` under pipefail falsely fails ~1 in 4
# (grep -q exits early, codesign gets SIGPIPE, pipefail reports failure).
SIGINFO="$(codesign -dv "$WORK/$APP" 2>&1 || true)"
[[ "$SIGINFO" == *"TeamIdentifier=$TEAM_ID"* ]] || die "this build isn't signed by Emazing Group, so nothing was installed."

if [ -n "${EGHUB_DEST_DIR:-}" ]; then DEST_DIR="$EGHUB_DEST_DIR"; mkdir -p "$DEST_DIR"   # testing only
elif [ -w /Applications ]; then DEST_DIR=/Applications
else DEST_DIR="$HOME/Applications"; mkdir -p "$DEST_DIR"; fi
DEST="$DEST_DIR/$APP"

# The process is the bundle executable, "eg-hub", not the display name.
if [ -z "${EGHUB_DEST_DIR:-}" ] && pgrep -x "eg-hub" >/dev/null 2>&1; then
  say "Closing the running EG Hub"
  osascript -e 'quit app "EG Hub"' >/dev/null 2>&1 || true
  sleep 2
fi

say "Installing to $DEST_DIR"
[ -d "$DEST" ] && mv "$DEST" "$WORK/previous.app"
ditto "$WORK/$APP" "$DEST"
[ -n "${EGHUB_NO_OPEN:-}" ] || open "$DEST"

cat <<EOF

Done. EG Hub $VERSION is installed and opening.

Next:
  1. Sign in with your work Google account.
  2. Allow the microphone and Accessibility when your Mac asks.
  3. Click where you want to type, press Ctrl+Shift+Space, talk, press it again.

EG Hub updates itself from now on. Stuck? Post a screenshot in #eg-hub-testing.
EOF
