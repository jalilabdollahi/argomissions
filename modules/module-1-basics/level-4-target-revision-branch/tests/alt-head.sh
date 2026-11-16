#!/bin/bash
# Correct too: HEAD follows the repo's default branch (main).
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application invoices --type merge -p '{"spec":{"source":{"targetRevision":"HEAD"}}}'
am_app_refresh invoices
am_argocd app sync invoices --timeout 120
am_wait_app invoices sync=Synced health=Healthy --timeout 120
