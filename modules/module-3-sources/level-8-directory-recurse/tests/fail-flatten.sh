#!/bin/bash
# Wrong: flatten the repo so the top-level path works. It deploys, but the team's layout is gone.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/inventory-stack/deploy"
for t in web db; do for f in deployment service; do git mv "$t/$f.yaml" "$t-$f.yaml"; done; done
am_player_push "$SANDBOX/inventory-stack" "flatten deploy/"
am_argocd app get inventory --refresh >/dev/null
am_argocd app sync inventory --timeout 120
am_wait_app inventory sync=Synced health=Healthy --timeout 120
