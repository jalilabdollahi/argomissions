#!/bin/bash
# Wrong: host key checking is disabled on the repository.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch secret repo-fleet-agent --type merge -p '{"stringData":{"insecure":"true"}}'
refresh_synced() { am_app_refresh fleet-agent; [ "$(am_app_sync fleet-agent)" = Synced ]; }
am_wait 60 refresh_synced || true
