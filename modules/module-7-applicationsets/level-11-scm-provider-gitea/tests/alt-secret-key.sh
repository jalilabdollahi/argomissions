#!/bin/bash
# Correct too: the Secret gets the key the ApplicationSet asks for, the ApplicationSet stays as it was.
set -euo pipefail
source "$AM_LIB"

tok="$(kubectl -n argocd get secret gitea-scm-token -o jsonpath='{.data.token}')"
kubectl -n argocd patch secret gitea-scm-token --type merge -p "{\"data\":{\"access-token\":\"$tok\"}}"
# a changed Secret is not watched: ask the ApplicationSet for a refresh instead of waiting for the error back-off
kubectl -n argocd annotate applicationset mesh-fleet argocd.argoproj.io/application-set-refresh=true --overwrite
for r in pinger quill ember; do am_wait_app "mesh-$r" sync=Synced health=Healthy --timeout 180; done
