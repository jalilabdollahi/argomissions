#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app get shopfront-root
am_argocd app manifests shopfront-root || true
cd "$SANDBOX/shopfront-fleet"
ls apps argocd/apps
am_argocd app set shopfront-root --path argocd/apps
am_argocd app get shopfront-root --refresh >/dev/null
am_wait_app shopfront-root sync=Synced --timeout 120
am_wait_app cart-svc sync=Synced health=Healthy --timeout 150
am_wait_app catalog-svc sync=Synced health=Healthy --timeout 150
