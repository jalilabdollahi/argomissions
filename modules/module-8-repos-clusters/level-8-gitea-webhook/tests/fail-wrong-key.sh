#!/bin/bash
# Wrong: copy the secret to another provider's key (github) - Gitea's deliveries are handled by the Gogs handler.
set -euo pipefail
source "$AM_LIB"

secret="$(kubectl -n argocd get secret argocd-secret -o jsonpath='{.data.webhook\.gitea\.secret}')"
kubectl -n argocd patch secret argocd-secret --type merge -p "{\"data\":{\"webhook.github.secret\":\"$secret\"}}" >/dev/null
sleep 3
