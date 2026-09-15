# EG Hub releases

Update feed for **EG Hub**, Emazing Group's internal Mac app (Team EG, EG Flow dictation, EG Note Taker).

- `updates/latest-stable.json` and `updates/latest-test.json` are the two update rings the app reads.
- Each GitHub release carries the notarized `EG Hub.app.tar.gz` and its minisign signature; the app verifies the signature against the public key baked into it before installing anything.
- Nothing here is source code. The app is useless without an allow-listed Team EG account.

Published by `scripts/publish-update.sh` in the private `eg-hub` repo.
