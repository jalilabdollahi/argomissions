#!/bin/bash
# Wrong: automated sync switched on by hand on the generated Application; the ApplicationSet takes it back.
set -euo pipefail
source "$AM_LIB"

am_argocd app set lumen-prod --sync-policy automated --auto-prune
sleep 12
