#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed parcel-api "$LEVEL_DIR/repo" "parcel-api chart 0.3.0"
cp "$LEVEL_DIR/assets/appset.yaml" "$SANDBOX/parcel-api-appset.yaml"
kubectl apply -f "$LEVEL_DIR/assets/appset.yaml" >/dev/null

for e in dev stage prod; do
  am_wait_app "parcel-api-$e" sync=Synced health=Healthy --timeout 150 \
    || { echo "setup: parcel-api-$e did not become healthy"; exit 1; }
done
am_setup_assert "prod still runs one replica" test "$(am_ready_replicas parcel-api parcel-prod)" = 1
am_setup_assert "prod answers the base banner" \
  bash -c 'source "$AM_LIB"; [ "$(am_http http://parcel-api.parcel-prod parcel-prod)" = "parcel-api prod" ]'
