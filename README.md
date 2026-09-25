# EG Hub releases

Update feed for **EG Hub**, Emazing Group's internal Mac app (EG Hub web, EG Flow dictation, EG Notetaker).

- `updates/latest-stable.json` and `updates/latest-test.json` are the two update rings the app reads.
- Each GitHub release carries the notarized `EG Hub.app.tar.gz` and its minisign signature; the app verifies the signature against the public key baked into it before installing anything.
- Nothing here is source code. The app is useless without an allow-listed Team EG account.

Published by `scripts/publish-update.sh` in the private `eg-hub` repo.

## Install (Emazing Group teammates)

Needs a Mac with an Apple chip (M1 or newer) and your work Google account. Open Terminal and paste:

```
curl -fsSL https://raw.githubusercontent.com/EmazingGroup/eg-hub-releases/main/install.sh | bash
```

It checks the download is signed by Emazing Group (Apple team FQJPY8W5U6) before installing anything, and installs the build named in `updates/latest-stable.json`, the same one the app's updater follows.

Meeting notes (EG Notetaker) are part of EG Hub: after you sign in, EG Hub sets them up by itself, and EG Hub > Settings > EG Note Taker shows anything that still needs a click. There is nothing separate to install.

To remove EG Hub and EG Notetaker (apps, background jobs, start-at-login), run:

```
curl -fsSL https://raw.githubusercontent.com/EmazingGroup/eg-hub-releases/main/uninstall.sh | bash
```

The apps go to the Trash; settings stay in `~/Library/Application Support/com.emazing.eghub` for a reinstall.

`install-notetaker.sh` stays only so old links keep working: it hands off to the setup EG Hub already runs. It is a published copy of `companion/macos-notifier/install-notetaker.sh` in the private eg-hub repo; keep them identical.
