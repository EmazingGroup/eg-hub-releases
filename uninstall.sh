#!/bin/bash
# Remove EG Hub and EG Notetaker from this Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/EmazingGroup/eg-hub-releases/main/uninstall.sh | bash
#
# Quits both apps, stops the notetaker's background job and EG Hub's
# start-at-login job, and moves the apps to the Trash (not deleted: drag them
# back out of the Trash to undo). Settings and downloaded models stay in
# ~/Library/Application Support/com.emazing.eghub, so a reinstall picks up where
# you left off. Your notes live in your EG Hub account, not on this Mac.
#
#   EGHUB_DRY_RUN=1   print what would happen, change nothing
set -uo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

DRY="${EGHUB_DRY_RUN:-}"
GUI="gui/$(id -u)"
say() { printf '==> %s\n' "$*"; }
run() { if [ -n "$DRY" ]; then printf '    would run: %s\n' "$*"; else "$@"; fi; }

NOTIFIER_LABEL="com.emazing.meetingnotifier"
NOTIFIER_PLIST="$HOME/Library/LaunchAgents/$NOTIFIER_LABEL.plist"
# tauri-plugin-autostart (MacosLauncher::LaunchAgent) names it after the app.
AUTOSTART_PLIST="$HOME/Library/LaunchAgents/EG Hub.plist"

found=0

if pgrep -x "eg-hub" >/dev/null 2>&1; then
  say "Quitting EG Hub"; found=1
  run osascript -e 'quit app "EG Hub"'
fi
if pgrep -x "EGMeetingNotifier" >/dev/null 2>&1 || launchctl print "$GUI/$NOTIFIER_LABEL" >/dev/null 2>&1; then
  say "Stopping EG Notetaker"; found=1
  run launchctl bootout "$GUI/$NOTIFIER_LABEL"
fi

for plist in "$NOTIFIER_PLIST" "$AUTOSTART_PLIST"; do
  if [ -f "$plist" ]; then
    say "Removing $(basename "$plist")"; found=1
    run mv "$plist" "$HOME/.Trash/"
  fi
done

for app in "/Applications/EG Hub.app" "$HOME/Applications/EG Hub.app" "/Applications/EGMeetingNotifier.app"; do
  if [ -d "$app" ]; then
    say "Moving $(basename "$app") to the Trash"; found=1
    dest="$HOME/.Trash/$(basename "$app")"
    [ -e "$dest" ] && dest="$HOME/.Trash/$(basename "$app" .app) $(date +%H%M%S).app"
    run mv "$app" "$dest"
  fi
done

if [ "$found" = 0 ]; then
  echo "EG Hub isn't installed on this Mac. Nothing to do."
else
  echo
  echo "Done. EG Hub and EG Notetaker are removed; the apps are in the Trash."
  echo "Your settings stay in ~/Library/Application Support/com.emazing.eghub if you reinstall."
fi
