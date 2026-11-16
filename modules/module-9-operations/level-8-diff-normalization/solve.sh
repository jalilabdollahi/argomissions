#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# What does the diff say?
am_argocd app diff ops-statusboard || true
# The blank `refresh:` in Git is null; the CRD turns it into its default, 30s. Say the value explicitly.
cd "$SANDBOX/statusboard-config"
sed -i.bak 's/^      refresh:$/      refresh: 30s/' deploy/statusboard.yaml && rm -f deploy/statusboard.yaml.bak
am_player_push "$SANDBOX/statusboard-config" "Make the panel refresh explicit"
am_argocd app get ops-statusboard --refresh >/dev/null
am_argocd app sync ops-statusboard --timeout 120
am_wait_app ops-statusboard sync=Synced health=Healthy --timeout 120
