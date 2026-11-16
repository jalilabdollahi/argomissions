#!/bin/bash
# Correct too: keep the root's destination, name namespace argocd on the child manifests in Git, clean up the orphans.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/billing-gitops"
for f in apps/invoice.yaml apps/dunning.yaml; do
  sed -i.bak 's/^metadata:/metadata:\n  namespace: argocd/' "$f" && rm "$f.bak"
done
am_player_push . "child Applications: explicit namespace argocd"
head="$(am_repo_head billing-gitops)"
am_app_refresh billing-root
am_wait_app billing-root rev="$head" --timeout 120
am_wait_app billing-root sync=OutOfSync --timeout 60
am_argocd app sync billing-root --prune --timeout 120
am_wait_app billing-root sync=Synced --timeout 120
am_wait_app invoice-api sync=Synced health=Healthy --timeout 150
am_wait_app dunning-worker sync=Synced health=Healthy --timeout 150
am_app_refresh invoice-api; am_app_refresh dunning-worker
am_wait_app invoice-api rev="$head" sync=Synced --timeout 120
am_wait_app dunning-worker rev="$head" sync=Synced --timeout 120
