#!/bin/bash
# Wrong: the manifest is fixed and pushed but nobody syncs the manual Application.
set -euo pipefail
source "$AM_LIB"

sed -i.bak 's#policy/v1beta1#policy/v1#' "$SANDBOX/billing/deploy/pdb.yaml" && rm "$SANDBOX/billing/deploy/pdb.yaml.bak"
am_player_push "$SANDBOX/billing" "pdb: policy/v1"
am_app_refresh billing
am_wait_app billing rev="$(am_repo_head billing)" --timeout 60
