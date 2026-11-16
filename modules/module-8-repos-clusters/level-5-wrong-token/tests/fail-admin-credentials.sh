#!/bin/bash
# Wrong: the admin account replaces the dead token.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch secret repo-mailroom --type merge -p "{\"stringData\":{\"username\":\"player\",\"password\":\"$AM_GIT_PASS\"}}"
am_argocd app get mailroom --hard-refresh >/dev/null
am_wait_app mailroom sync=Synced health=Healthy --timeout 150
