#!/bin/bash
# Wrong: recurse with no exclude. The retired component comes back to life.
set -euo pipefail
source "$AM_LIB"

am_argocd app create lighthouse-bootstrap --repo "$(am_repo_url lighthouse-gitops)" --path platform --revision main \
  --dest-server https://kubernetes.default.svc --dest-namespace argocd --directory-recurse --sync-policy automated
am_wait_app lighthouse-bootstrap sync=Synced --timeout 180
am_wait_app lighthouse-billing-legacy sync=Synced health=Healthy --timeout 240 || true
