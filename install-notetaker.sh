#!/bin/bash
# EG Notetaker is part of EG Hub now. This file stays so an old link keeps working.
#
#   curl -fsSL https://raw.githubusercontent.com/EmazingGroup/eg-hub-releases/main/install-notetaker.sh | bash
#
# (2026-09-24) This used to install EGMeetingNotifier.app on its own. That was
# never enough: turning a meeting into a note also needs the notetaker's
# runtime, its speech model, its background jobs and the person's sync key,
# and only a repo checkout could set those up. EG Hub now does all of it by
# itself after sign-in (src-tauri/resources/notetaker-setup.sh in eg-hub). So
# this runs that same setup when this Mac's EG Hub has it, and otherwise says
# what will happen, without installing anything half-way.
set -uo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

for APP in "/Applications/EG Hub.app" "$HOME/Applications/EG Hub.app"; do
  SETUP="$APP/Contents/Resources/resources/notetaker-setup.sh"
  if [ -f "$SETUP" ]; then
    echo "==> Meeting notes are part of EG Hub now. Setting them up the same way EG Hub does."
    exec bash "$SETUP" --force
  fi
  if [ -d "$APP" ]; then
    cat <<MSG

Meeting notes are part of EG Hub now, so there is nothing separate to install.
Your EG Hub will set them up by itself after its next update: EG Hub updates
itself, and once it has, open EG Hub > Settings and the EG Note Taker card
shows what is ready and what still needs a click.
MSG
    exit 0
  fi
done

cat <<'MSG'

Meeting notes are part of EG Hub now. Install EG Hub, sign in, and it sets up
meeting notes by itself:

  curl -fsSL https://raw.githubusercontent.com/EmazingGroup/eg-hub-releases/main/install.sh | bash
MSG
