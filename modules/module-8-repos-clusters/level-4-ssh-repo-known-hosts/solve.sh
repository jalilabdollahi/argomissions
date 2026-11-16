#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# collect the server's host keys the way an operator would, from inside the cluster
kubectl -n argocd exec deploy/argocd-repo-server -c argocd-repo-server -- ssh-keyscan gitea.gitea.svc.cluster.local 2>/dev/null \
  | am_argocd cert add-ssh --batch
refresh_synced() { am_app_refresh fleet-agent; [ "$(am_app_sync fleet-agent)" = Synced ]; }
am_wait 170 refresh_synced || { echo "fleet-agent did not sync"; exit 1; }
am_wait_app fleet-agent sync=Synced health=Healthy --timeout 60
