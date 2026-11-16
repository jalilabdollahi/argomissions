#!/bin/bash
# Wrong: ignoreApplicationDifferences with a pointer that does not exist in an Application; nothing is ignored.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset feedhub --type merge \
  -p '{"spec":{"ignoreApplicationDifferences":[{"jsonPointers":["/spec/targetRevision"]}]}}'
sleep 3
am_argocd app set feedhub-prod --revision hotfix-1.8.1
sleep 10
