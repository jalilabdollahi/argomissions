#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed lumen-gateway "$LEVEL_DIR/repo" "lumen-gateway v1"
cp "$LEVEL_DIR/assets/appset.yaml" "$SANDBOX/lumen-appset.yaml"
kubectl apply -f "$LEVEL_DIR/assets/appset.yaml" >/dev/null

for e in dev stage prod; do
  have_app() { am_app_exists "lumen-$e"; }
  am_wait 60 have_app || { echo "setup: lumen-$e was not generated"; exit 1; }
  am_wait_app "lumen-$e" sync=OutOfSync --timeout 90 || { echo "setup: lumen-$e not OutOfSync"; exit 1; }
  am_app_sync_now "lumen-$e"
  am_wait_app "lumen-$e" sync=Synced health=Healthy op=Succeeded --timeout 150 \
    || { echo "setup: lumen-$e did not sync"; exit 1; }
done

# Release v2 lands on main; nobody syncs.
am_repo_commit lumen-gateway "$LEVEL_DIR/assets/v2" "Release lumen-gateway v2" >/dev/null 2>&1
for e in dev stage prod; do am_app_refresh "lumen-$e"; done
for e in dev stage prod; do
  am_wait_app "lumen-$e" sync=OutOfSync --timeout 90 || { echo "setup: lumen-$e did not notice v2"; exit 1; }
done
