#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# v1.0 is live, deployed by Argo CD
am_repo_seed ticket-desk "$LEVEL_DIR/repo" "ticket-desk v1.0 manifests"
kubectl create namespace helpdesk >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh ticket-desk
am_wait_app ticket-desk sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
am_argocd app sync ticket-desk --timeout 120 >/dev/null
am_wait_app ticket-desk sync=Synced health=Healthy --timeout 120 || { echo "setup: v1.0 did not deploy"; exit 1; }

# a colleague relabels everything, including the Deployment's selector
am_repo_commit ticket-desk "$LEVEL_DIR/assets/relabel" "relabel: adopt app.kubernetes.io/name labels, release v1.1"
am_app_refresh ticket-desk
am_wait_app ticket-desk sync=OutOfSync --timeout 90 || { echo "setup: new commit not seen"; exit 1; }
am_argocd app sync ticket-desk --timeout 120 >/dev/null 2>&1 || true
am_wait_app ticket-desk op=Failed opmsg="immutable" --timeout 60 || { echo "setup: sync did not fail with an immutable-field error"; exit 1; }

am_workspace_clone ticket-desk
