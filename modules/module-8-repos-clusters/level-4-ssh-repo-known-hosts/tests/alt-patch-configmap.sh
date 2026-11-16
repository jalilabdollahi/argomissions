#!/bin/bash
# Correct too: put the host keys straight into argocd-ssh-known-hosts-cm.
set -euo pipefail
source "$AM_LIB"

keys="$(kubectl -n argocd exec deploy/argocd-repo-server -c argocd-repo-server -- ssh-keyscan gitea.gitea.svc.cluster.local 2>/dev/null | grep -v '^#')"
cur="$(kubectl -n argocd get cm argocd-ssh-known-hosts-cm -o jsonpath='{.data.ssh_known_hosts}')"
kubectl -n argocd patch cm argocd-ssh-known-hosts-cm --type merge \
  -p "$(jq -n --arg k "$cur"$'\n'"$keys" '{data:{ssh_known_hosts:$k}}')"
refresh_synced() { am_app_refresh fleet-agent; [ "$(am_app_sync fleet-agent)" = Synced ]; }
am_wait 170 refresh_synced
am_wait_app fleet-agent sync=Synced health=Healthy --timeout 60
