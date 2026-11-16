#!/bin/bash
# Wrong: an `allow` window is added next to the deny window. Deny wins, so nothing changes.
set -euo pipefail
source "$AM_LIB"

am_argocd proj windows add billing-core --kind allow --schedule '* * * * *' --duration 24h \
  --applications '*' --manual-sync
am_argocd app sync statement-api --timeout 60 || true
