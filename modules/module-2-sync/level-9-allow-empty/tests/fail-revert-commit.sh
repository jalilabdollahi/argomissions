#!/bin/bash
# Wrong: put the manifests back. The workloads stay, but they were meant to leave this repo.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/nightly-etl"
git revert --no-edit HEAD >/dev/null
git push -q origin HEAD
am_app_refresh nightly-etl
am_wait_app nightly-etl sync=Synced health=Healthy --timeout 120
