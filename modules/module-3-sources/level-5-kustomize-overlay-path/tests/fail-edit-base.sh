#!/bin/bash
# Wrong: copy the production settings into the shared base (staging would inherit them).
set -euo pipefail
source "$AM_LIB"

am_workspace_clone inventory-sync
cd "$SANDBOX/inventory-sync"
cp kustomize/overlays/prod/production-patch.yaml kustomize/base/deployment.yaml.new
python3 - <<'Y'
import re
p = "kustomize/base/deployment.yaml"
s = open(p).read().replace("replicas: 1", "replicas: 3").replace("inventory-sync base", "inventory-sync prod")
open(p, "w").write(s)
Y
rm kustomize/base/deployment.yaml.new
am_player_push . "Production settings in base"
am_app_refresh inventory-sync
am_argocd app sync inventory-sync --timeout 120
am_wait_app inventory-sync sync=Synced health=Healthy rev="$(am_repo_head inventory-sync)" --timeout 120
kubectl -n inventory rollout status deploy/inventory-sync --timeout=90s
