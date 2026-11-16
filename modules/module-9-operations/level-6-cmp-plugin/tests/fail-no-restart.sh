#!/bin/bash
# Wrong: the plugin ConfigMap is fixed but the sidecar is never restarted, so it keeps the old discover rule.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd get configmap kv-render-plugin -o json \
  | jq '.data["plugin.yaml"] |= sub("\\*\\*/app\\.config"; "**/app.conf")' | kubectl replace -f - >/dev/null
am_app_refresh label-printer hard
sleep 10
