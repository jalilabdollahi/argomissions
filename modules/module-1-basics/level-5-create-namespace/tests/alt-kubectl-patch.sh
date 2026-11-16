#!/bin/bash
# Correct too: patch the Application's syncPolicy, then sync (the sync operation must carry the option).
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application ledger --type merge -p '{"spec":{"syncPolicy":{"syncOptions":["CreateNamespace=true"]}}}'
am_app_sync_now ledger
am_wait_app ledger op=Succeeded sync=Synced health=Healthy --timeout 120
