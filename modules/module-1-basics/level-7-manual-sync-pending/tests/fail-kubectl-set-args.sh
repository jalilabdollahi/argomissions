#!/bin/bash
# Wrong: hot-patch the live Deployment to the new version instead of syncing.
set -euo pipefail
source "$AM_LIB"

kubectl -n search patch deployment search-api --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["-text=search-api v2.3","-listen=:5678"]}]'
kubectl -n search rollout status deploy/search-api --timeout=90s
am_app_refresh search-api
sleep 5
