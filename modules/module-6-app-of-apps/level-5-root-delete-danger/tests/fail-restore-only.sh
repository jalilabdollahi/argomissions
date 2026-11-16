#!/bin/bash
# Partial: the service is restored, nothing prevents the next accident.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/inventory-gitops"
git revert --no-edit HEAD >/dev/null
git push -q origin HEAD
head="$(am_repo_head inventory-gitops)"
am_app_refresh inventory-root
am_wait_app inventory-root rev="$head" sync=Synced --timeout 120
am_wait_app stock-api sync=Synced health=Healthy --timeout 150
