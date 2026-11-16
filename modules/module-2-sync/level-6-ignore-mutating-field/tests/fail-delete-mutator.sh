#!/bin/bash
# Wrong: the controller of another team is removed, then a sync restores Git's label.
set -euo pipefail
source "$AM_LIB"

kubectl delete namespace profiles-finops --wait=true
am_argocd app sync profile-svc --timeout 120
am_wait_app profile-svc sync=Synced health=Healthy --timeout 120
