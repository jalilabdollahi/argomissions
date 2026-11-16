#!/bin/bash
# Wrong: the project created by hand. The children heal, but Git (and a fresh cluster) still lack it.
set -euo pipefail
source "$AM_LIB"

kubectl apply -f "$LEVEL_DIR/assets/project.yaml"
for c in trace-collector trace-query; do
  am_app_refresh "$c"
  am_wait_app "$c" sync=Synced health=Healthy --timeout 150
done
