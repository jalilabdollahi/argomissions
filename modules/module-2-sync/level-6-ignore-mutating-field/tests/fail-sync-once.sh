#!/bin/bash
# Wrong: a manual sync restores Git's label; seconds later the controller stamps it again.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync profile-svc --timeout 120
am_wait_app profile-svc sync=Synced health=Healthy --timeout 120
sleep 20
