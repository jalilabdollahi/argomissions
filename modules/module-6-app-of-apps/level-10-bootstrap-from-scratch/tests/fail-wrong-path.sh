#!/bin/bash
# Wrong: the root points at the repo root with recurse and takes the workloads too, deploying them into argocd.
set -euo pipefail
source "$AM_LIB"

am_argocd app create lighthouse-bootstrap --repo "$(am_repo_url lighthouse-gitops)" --path . --revision main \
  --dest-server https://kubernetes.default.svc --dest-namespace argocd --directory-recurse --directory-exclude 'platform/apps/_archive/*'
am_argocd app sync lighthouse-bootstrap --timeout 240 || true
am_wait 60 true
