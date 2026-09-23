#!/bin/bash
# EG Notetaker: one-command install for a teammate's Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/EmazingGroup/eg-hub-releases/main/install-notetaker.sh | bash
#
# (2026-09-23) Served from the PUBLIC eg-hub-releases repo, next to the signed
# builds it installs, so a teammate needs no GitHub account and no gh CLI. The
# source copy lives in the private eg-hub repo at
# companion/macos-notifier/install-notetaker.sh; keep the two identical.
#   (or, with a zip someone sent you)   EG_NOTIFIER_ZIP=~/Downloads/EGMeetingNotifier-xxxx.zip bash install-notetaker.sh
#
# What Jose's 2026-09-09 test on a free Zoom account taught us, each one now a
# step this script owns so the next person never sees it:
#   1. An ad-hoc build can never hold the Accessibility grant (macOS binds the
#      row to the signing identity). Only the Developer ID signed release is
#      installed here, never a local build.
#   2. The grant itself: the app raises the system prompt (which adds it to
#      the list), this script opens the pane and waits until it reads back
#      as granted. No hunting for the pane, no dragging the app in.
#   3. Siri's corespeechd kept the "someone is in a call" signal on forever;
#      the release carries the denylist, and the self-test proves it.
#   4. Zoom speaks "X has joined" when an accessibility client is attached;
#      if Zoom is running and idle, its Screen Reader Alerts are switched off.
#   5. Nothing on a non-Brian Mac turned captured captions into a transcript
#      (fixed in eg-skills 808a335); the exporter is not this script's job,
#      but the log path and the first-run check are printed at the end.
#
# Idempotent: run it again to update to the latest release.
set -euo pipefail
# A Terminal with a trimmed PATH must still find codesign, ditto, plutil, launchctl.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# eg-meeting-companion was archived 2026-09-17 once EG Hub absorbed its source
# (eg-hub#18), so it can never gain another release. Notetaker builds publish
# here instead, alongside EG Hub's own. Safe to share one repo because each
# consumer filters for its own tag prefix: EG Hub's release-on-merge.sh takes
# startswith("v"), the line below takes startswith("notifier-").
REPO="EmazingGroup/eg-hub-releases"
APP_NAME="EGMeetingNotifier.app"
DEST="/Applications/$APP_NAME"
BIN="$DEST/Contents/MacOS/EGMeetingNotifier"
LABEL="com.emazing.meetingnotifier"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/eg-meeting-notifier.log"
GUI="gui/$(id -u)"
WORK="$(mktemp -d /tmp/eg-notetaker-install.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nSTOPPED: %s\n' "$*" >&2; exit 1; }

# ---- 0. never install into a live call -------------------------------------
if pgrep -x CptHost >/dev/null 2>&1; then
  die "a Zoom meeting is running on this Mac; finish it, then run this again."
fi

# ---- 1. get the signed release ---------------------------------------------
say "Getting the signed EG Notetaker"
ZIP="${EG_NOTIFIER_ZIP:-}"
if [ -z "$ZIP" ]; then
  # Plain curl against the public GitHub API: no gh, no GitHub account.
  # (2026-09-23) This used `gh release list --limit 20`, which had already
  # stopped working for everyone: EG Hub's own v0.1.x releases pushed the
  # newest notifier-* release down to #31. Scan 100, newest first. plutil
  # reads JSON and ships with every Mac, so there is no jq/python dependency.
  API="$WORK/releases.json"
  curl -fsSL "https://api.github.com/repos/$REPO/releases?per_page=100" -o "$API" \
    || die "couldn't reach GitHub. Check your internet connection and run this again."
  TAG=""; ZIP_URL=""
  i=0
  while tag="$(plutil -extract "$i.tag_name" raw -o - "$API" 2>/dev/null)"; do
    pre="$(plutil -extract "$i.prerelease" raw -o - "$API" 2>/dev/null || echo true)"
    case "$tag" in
      notifier-*)
        if [ "$pre" = "false" ]; then
          j=0
          while name="$(plutil -extract "$i.assets.$j.name" raw -o - "$API" 2>/dev/null)"; do
            case "$name" in *.zip) ZIP_URL="$(plutil -extract "$i.assets.$j.browser_download_url" raw -o - "$API")";; esac
            j=$((j + 1))
          done
          TAG="$tag"; break
        fi;;
    esac
    i=$((i + 1))
  done
  [ -n "$TAG" ] && [ -n "$ZIP_URL" ] || die "no EG Notetaker release found on $REPO. Ask in #eg-hub-testing."
  say "Downloading release $TAG"
  curl -fL --progress-bar "$ZIP_URL" -o "$WORK/$TAG.zip" || die "download failed. Run this again."
  ZIP="$WORK/$TAG.zip"
fi
[ -f "$ZIP" ] || die "zip not found: $ZIP"

# ---- 2. unpack and verify the signature before touching /Applications ------
say "Checking the signature"
ditto -x -k "$ZIP" "$WORK/unpacked"
SRC="$(find "$WORK/unpacked" -maxdepth 2 -name "$APP_NAME" | head -1)"
[ -d "$SRC" ] || die "$APP_NAME not inside the zip"
codesign --verify --deep --strict "$SRC" 2>/dev/null || die "signature check failed; this is not the signed build"
# TeamIdentifier is printed by plain -dv; the Authority lines need --verbose=2+.
# Capture first, then match. `codesign ... | grep -q` under pipefail failed 8
# times in 30 on 2026-09-23: grep -q exits on the match, codesign takes SIGPIPE
# writing its remaining lines, and pipefail reports the correctly signed build
# as unsigned.
SIGINFO="$(codesign -dv "$SRC" 2>&1 || true)"
if [[ "$SIGINFO" != *"TeamIdentifier=FQJPY8W5U6"* ]]; then
  die "this build is not signed with the EmazingLights Developer ID (team FQJPY8W5U6); an ad-hoc build can never hold the Accessibility grant"
fi
xattr -dr com.apple.quarantine "$SRC" 2>/dev/null || true
[ -x "$SRC/Contents/MacOS/eg-recorder" ] || die "the recorder binary is missing from the bundle"

# ---- 3. stop the old one, swap the app, start the new one ------------------
say "Installing to /Applications"
launchctl bootout "$GUI/$LABEL" 2>/dev/null || true
pkill -x EGMeetingNotifier 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$SRC" "$DEST"
[ -x "$BIN" ] || die "copy failed; $BIN is not executable"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>KeepAlive</key>
	<dict><key>SuccessfulExit</key><false/></dict>
	<key>Label</key><string>$LABEL</string>
	<key>ProcessType</key><string>Interactive</string>
	<key>ProgramArguments</key>
	<array><string>$BIN</string></array>
	<key>RunAtLoad</key><true/>
	<key>StandardErrorPath</key><string>$LOG</string>
	<key>StandardOutPath</key><string>$LOG</string>
</dict>
</plist>
EOF
launchctl bootstrap "$GUI" "$PLIST" 2>/dev/null || launchctl kickstart -k "$GUI/$LABEL"
sleep 2
pgrep -x EGMeetingNotifier >/dev/null || die "the notifier did not start; see $LOG"

# ---- 4. Accessibility: prompt, open the pane, wait for the switch -----------
say "Accessibility (this is the one thing macOS makes you click)"
if "$BIN" --accessibility-status >/dev/null 2>&1; then
  echo "    already granted."
else
  "$BIN" --request-accessibility >/dev/null 2>&1 || true
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  echo "    System Settings is open on Privacy & Security > Accessibility."
  echo "    Turn ON the switch next to EGMeetingNotifier (if an old EGMeetingNotifier row is there too, remove it with the minus button)."
  echo -n "    waiting"
  for i in $(seq 1 180); do
    if "$BIN" --accessibility-status >/dev/null 2>&1; then echo; echo "    granted."; break; fi
    echo -n "."; sleep 2
    [ "$i" -eq 180 ] && { echo; die "still not granted after 6 minutes. Flip the switch, then run this script again (it is safe to re-run)."; }
  done
fi

# ---- 5. notes open in EG Hub, not a browser --------------------------------
# The 2026-09-08 cutover ("everything should open up in EG Hub instead of the
# team app going forward") shipped the notifier code that deep-links a note
# into EG Hub, but nothing ever set the preference that code reads. The string
# NoteBrowser appears in exactly one file in this repo and zero times in the
# shipped eg-hub binary, and there is no UI for it anywhere -- so the only way
# a teammate had it pointing at EG Hub was to know about an undocumented
# `defaults write`. Jose, the first tester, still had "Google Chrome" from
# before the cutover and every note for a week opened in Chrome.
#
# This runs ONCE. The marker below is what makes it once: a person who later
# decides they want notes in a browser sets the key and this never touches it
# again. An existing value that is not a browser is never overwritten at all.
say "Where meeting notes open"
HUB_APP="/Applications/EG Hub.app"
APP_DOM="com.emazinggroup.egmeetingcompanion"   # the app's real bundle id
SPEC_DOM="com.emazinggroup.EGMeetingNotifier"   # the domain the notifier was spec'd to read
MARKER="NoteBrowserMigratedToEGHub"

if [ ! -d "$HUB_APP" ]; then
  echo "    EG Hub is not installed; leaving the setting alone."
  echo "    Install EG Hub and re-run this script to point notes at it."
else
  done_already="$(defaults read "$APP_DOM" "$MARKER" 2>/dev/null || true)"
  cur_app="$(defaults read "$APP_DOM" NoteBrowser 2>/dev/null || true)"
  cur_spec="$(defaults read "$SPEC_DOM" NoteBrowser 2>/dev/null || true)"
  # Same precedence as EGResolveNoteBrowser() in main.m: app domain, then the
  # spec'd suite, then unset.
  cur="$cur_app"; [ -n "$cur" ] || cur="$cur_spec"

  if [ "$done_already" = "1" ]; then
    echo "    already done once; leaving it on '${cur:-EG Hub (unset)}'."
  else
    # Only a browser (or nothing) gets migrated. Anything else is a deliberate
    # choice this script has no business overwriting.
    migrate=no
    case "$(printf '%s' "$cur" | tr '[:upper:]' '[:lower:]')" in
      ""|default|safari|"google chrome"|chrome|chromium|firefox|"brave browser"|brave|arc|"microsoft edge"|edge|opera|vivaldi)
        migrate=yes ;;
    esac

    if [ "$migrate" = no ]; then
      echo "    '$cur' is not a browser; leaving it alone."
    else
      defaults write "$APP_DOM"  NoteBrowser "EG Hub"
      defaults write "$SPEC_DOM" NoteBrowser "EG Hub"
      defaults write "$APP_DOM"  "$MARKER" -bool true
      if [ -z "$cur" ]; then
        echo "    was not set (notes were opening in Safari); now: EG Hub."
      else
        echo "    was '$cur'; now: EG Hub."
      fi
      # The running notifier read the old value at launch, so restart it or the
      # very next meeting still opens in the old browser.
      launchctl kickstart -k "$GUI/$LABEL" >/dev/null 2>&1 || true
      sleep 2
      pgrep -x EGMeetingNotifier >/dev/null || die "the notifier did not come back after the restart; see $LOG"
      echo "    notifier restarted so it picks this up."
    fi
  fi
fi

# ---- 6. proofs ---------------------------------------------------------------
say "Self-test"
"$BIN" --self-test-mic-denylist 2>&1 | tail -1

if pgrep -x zoom.us >/dev/null 2>&1; then
  say "Zoom is open: switching off its spoken join/leave alerts (the Settings window will flash for a few seconds)"
  "$BIN" --zoom-alerts-off 2>&1 | tail -1 || echo "    could not change it; do it once by hand: Zoom > Settings > Accessibility > Screen Reader Alerts > uncheck all"
else
  echo "    Zoom is not running; start Zoom once and run this again to switch off its spoken join/leave alerts, or uncheck them in Zoom > Settings > Accessibility."
fi

# ---- 7. what happens next ------------------------------------------------------
cat <<EOF

DONE. EG Notetaker $(defaults read "$DEST/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "") is installed and running.

What to expect on your next Zoom meeting (free Zoom account):
  - a prompt to record appears within a few seconds of joining; press Record
  - the app turns Zoom's captions on by itself and reads them (that is the transcript)
  - when the call ends the recording stops on its own, and the note opens with
    Transcript: "Source: Zoom" and Zoom's names on each line
Log to send if something is off:  $LOG
Lines that mean it is working:    "captions: enabled via ..." then "caption table found"
EOF
