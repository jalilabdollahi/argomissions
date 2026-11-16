#!/bin/bash
# Correct too: Git stops declaring the label the other controller owns.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/profile-svc"
sed -i.bak '/cost-center: unassigned/d' deploy/deployment.yaml && rm deploy/deployment.yaml.bak
am_player_push . "profile-svc: cost-center belongs to finops"
am_app_refresh profile-svc
am_wait_app profile-svc sync=Synced health=Healthy rev="$(am_repo_head profile-svc)" --timeout 120
