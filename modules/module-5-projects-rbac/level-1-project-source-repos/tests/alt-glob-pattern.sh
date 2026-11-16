#!/bin/bash
# Correct too: a narrower glob that names the intake-* repositories of the team.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject claims --type merge \
  -p '{"spec":{"sourceRepos":["http://gitea.gitea.svc.cluster.local:3000/platform/claims-*","http://gitea.gitea.svc.cluster.local:3000/platform/intake-*"]}}'
am_app_refresh claims-intake
am_wait_app claims-intake sync=Synced health=Healthy --timeout 150
