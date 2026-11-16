#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set ledger --sync-option CreateNamespace=true
am_argocd app sync ledger --timeout 120
am_argocd app wait ledger --health --timeout 120
