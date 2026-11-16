#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed geo-edge "$LEVEL_DIR/repo" "geo-edge chart 0.1.0"
# A re-seeded repo gets new commit SHAs, but Argo CD caches branch -> commit lookups (in Redis) for a minute:
# start every run from an empty cache so that the generators and Applications see this run's repo.
kubectl -n argocd exec deploy/argocd-redis -c redis -- sh -c 'redis-cli -a "$REDIS_PASSWORD" flushall' >/dev/null 2>&1 || true
cp "$LEVEL_DIR/assets/appset.yaml" "$SANDBOX/geo-edge-appset.yaml"
kubectl apply -f "$LEVEL_DIR/assets/appset.yaml" >/dev/null

for r in us-east ap-south; do
  am_wait_app "geo-edge-$r" sync=Synced health=Healthy --timeout 150 || { echo "setup: geo-edge-$r did not become healthy"; exit 1; }
done
am_setup_assert "no eu-west Application" bash -c '! kubectl -n argocd get application geo-edge-eu-west'
