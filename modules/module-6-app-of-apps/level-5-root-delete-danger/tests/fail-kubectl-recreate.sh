#!/bin/bash
# Wrong: the Application recreated by hand from the old manifest. The service returns, Git still lacks it.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/inventory-gitops"
git show HEAD~1:apps/api.yaml | kubectl apply -f - 2>/dev/null
am_wait_app stock-api sync=Synced health=Healthy --timeout 150
