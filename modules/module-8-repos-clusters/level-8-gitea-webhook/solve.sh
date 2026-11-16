#!/bin/bash
set -euo pipefail
source "$AM_LIB"

secret="$(kubectl -n argocd get secret argocd-secret -o jsonpath='{.data.webhook\.gitea\.secret}')"
kubectl -n argocd patch secret argocd-secret --type merge -p "{\"data\":{\"webhook.gogs.secret\":\"$secret\"}}" >/dev/null
sleep 3
