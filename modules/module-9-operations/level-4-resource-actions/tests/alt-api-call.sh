#!/bin/bash
# Correct too: what the UI button does, the same API call made with a session token.
set -euo pipefail
source "$AM_LIB"

token="$(curl -fsS -X POST -H 'Content-Type: application/json' -d "{\"username\":\"admin\",\"password\":\"$AM_ARGOCD_PASSWORD\"}" \
  "http://$AM_ARGOCD_ADDR/api/v1/session" | jq -r .token)"
curl -fsS -X POST -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
  -d '"restart"' \
  "http://$AM_ARGOCD_ADDR/api/v1/applications/tollbooth/resource/actions?namespace=tollbooth&resourceName=tollbooth&kind=Deployment&group=apps&version=v1" >/dev/null
kubectl -n tollbooth rollout status deploy/tollbooth --timeout=90s
am_wait_app tollbooth sync=Synced health=Healthy --timeout 120
