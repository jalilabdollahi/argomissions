#!/bin/bash
# Wrong: an entry for the right host name but with a key that is not the server's (mismatch, handshake still fails).
set -euo pipefail
source "$AM_LIB"

ssh-keygen -q -t ed25519 -N "" -f "$AM_TMP/other"
echo "gitea.gitea.svc.cluster.local $(cut -d' ' -f1,2 "$AM_TMP/other.pub")" | am_argocd cert add-ssh --batch
refresh_synced() { am_app_refresh fleet-agent; [ "$(am_app_sync fleet-agent)" = Synced ]; }
am_wait 90 refresh_synced || true
