#!/bin/bash
# Correct too: a different glob (any _archive folder) with the CLI.
set -euo pipefail
source "$AM_LIB"

am_argocd app create lighthouse-bootstrap --repo "$(am_repo_url lighthouse-gitops)" --path platform --revision main \
  --dest-server https://kubernetes.default.svc --dest-namespace argocd --directory-recurse \
  --directory-exclude '**/_archive/*'
am_argocd app sync lighthouse-bootstrap --timeout 240
am_wait_app lighthouse-bootstrap sync=Synced health=Healthy --timeout 120
for a in lighthouse-cache lighthouse-gateway lighthouse-catalog; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 240
done
