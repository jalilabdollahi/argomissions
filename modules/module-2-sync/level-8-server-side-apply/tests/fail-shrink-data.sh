#!/bin/bash
# Wrong: cut the export down until it fits. The sync passes, the data is gone.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/host-registry"
"$AM_PYTHON" - <<'PY'
import yaml
p = "deploy/host-inventory.yaml"
d = yaml.safe_load(open(p))
d["data"]["hosts.txt"] = "\n".join(d["data"]["hosts.txt"].splitlines()[:2000]) + "\n"
yaml.safe_dump(d, open(p, "w"), default_style=None)
PY
am_player_push . "trim host export to the first 2000 hosts"
am_app_refresh host-registry
am_wait_app host-registry sync=OutOfSync --timeout 60 || true
am_argocd app sync host-registry --timeout 120
am_wait_app host-registry sync=Synced health=Healthy --timeout 120
