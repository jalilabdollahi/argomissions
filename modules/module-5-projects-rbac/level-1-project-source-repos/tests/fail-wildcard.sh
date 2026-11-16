#!/bin/bash
# Wrong: open the project to every repository.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject claims --type merge -p '{"spec":{"sourceRepos":["*"]}}'
am_app_refresh claims-intake
am_wait_app claims-intake sync=Synced health=Healthy --timeout 150
