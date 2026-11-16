#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed pricing-api "$LEVEL_DIR/repo" "pricing-api v2.0 manifests"
kubectl create namespace pricing >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh pricing-api
am_wait_app pricing-api sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync did not settle"; exit 1; }

# During last night's incident somebody edited the live objects by hand and never wrote it down in Git.
kubectl -n pricing scale deploy/pricing-api --replicas=5 >/dev/null
kubectl -n pricing patch configmap pricing-rules --type merge -p '{"data":{"max-discount-percent":"40"}}' >/dev/null
am_wait_app pricing-api sync=OutOfSync --timeout 90 || { echo "setup: drift not detected"; exit 1; }
sleep 15   # long enough to prove that plain automated sync leaves the drift alone
am_setup_assert "drift is still there" bash -c '[ "$(kubectl -n pricing get deploy pricing-api -o jsonpath="{.spec.replicas}")" = 5 ]'
am_setup_assert "still OutOfSync" bash -c '[ "$(kubectl -n argocd get application pricing-api -o jsonpath="{.status.sync.status}")" = OutOfSync ]'
am_workspace_clone pricing-api
