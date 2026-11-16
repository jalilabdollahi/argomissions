#!/bin/bash
# Wrong: bend the Application to the project's convention (clinic-pharmacy) instead of the real namespace.
set -euo pipefail
source "$AM_LIB"

kubectl create namespace clinic-pharmacy
kubectl -n argocd patch application rx-dispatch --type merge -p '{"spec":{"destination":{"namespace":"clinic-pharmacy"}}}'
am_app_refresh rx-dispatch
am_wait_app rx-dispatch sync=Synced health=Healthy --timeout 150
