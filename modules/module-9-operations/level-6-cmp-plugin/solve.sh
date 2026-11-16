#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The discover rule looks for app.config, the repo has app.conf.
kubectl -n argocd get configmap kv-render-plugin -o json \
  | jq '.data["plugin.yaml"] |= sub("\\*\\*/app\\.config"; "**/app.conf")' | kubectl replace -f - >/dev/null
# The sidecar reads plugin.yaml at start-up only.
kubectl -n argocd rollout restart deploy/argocd-repo-server
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s
am_app_refresh label-printer hard
am_wait_app label-printer sync=Synced health=Healthy op=Succeeded --timeout 180
