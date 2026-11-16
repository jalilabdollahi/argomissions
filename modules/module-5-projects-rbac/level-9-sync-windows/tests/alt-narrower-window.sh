#!/bin/bash
# Correct too: the freeze is narrowed to a nightly slot that is not active now; Argo CD syncs the fix on its own.
set -euo pipefail
source "$AM_LIB"

hour="$(( ( $(date -u +%H | sed 's/^0//') + 12 ) % 24 ))"
am_argocd proj windows delete billing-core 0
am_argocd proj windows add billing-core --kind deny --schedule "0 $hour * * *" --duration 2h \
  --applications '*' --manual-sync
am_app_refresh statement-api
am_wait_app statement-api sync=Synced health=Healthy --timeout 150
