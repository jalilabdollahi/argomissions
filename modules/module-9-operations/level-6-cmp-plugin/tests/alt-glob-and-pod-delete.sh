#!/bin/bash
# Correct too: a wider glob, and the repo-server pod deleted by hand instead of a rollout restart.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd get configmap kv-render-plugin -o json \
  | jq '.data["plugin.yaml"] |= sub("\\*\\*/app\\.config"; "**/*.conf")' | kubectl replace -f - >/dev/null
kubectl -n argocd delete pod -l app.kubernetes.io/name=argocd-repo-server --wait=true >/dev/null
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s
am_app_refresh label-printer hard
am_wait_app label-printer sync=Synced health=Healthy op=Succeeded --timeout 180
