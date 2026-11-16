#!/bin/bash
# Correct too: patch the Application resource, then sync.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application catalog --type merge -p '{"spec":{"source":{"path":"deploy/catalog"}}}'
am_app_refresh catalog
am_argocd app sync catalog --timeout 120
am_wait_app catalog sync=Synced health=Healthy --timeout 120
