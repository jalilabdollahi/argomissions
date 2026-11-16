#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed studio-platform "$LEVEL_DIR/repo" "studio services v1 and shared defaults"
# A re-seeded repo gets new commit SHAs, but Argo CD caches branch -> commit lookups (in Redis) for a minute:
# start every run from an empty cache so that the generators and Applications see this run's repo.
kubectl -n argocd exec deploy/argocd-redis -c redis -- sh -c 'redis-cli -a "$REDIS_PASSWORD" flushall' >/dev/null 2>&1 || true
cp "$LEVEL_DIR/assets/appset.yaml" "$SANDBOX/studio-appset.yaml"
kubectl apply -f "$LEVEL_DIR/assets/appset.yaml" >/dev/null


# The repo-server caches branch -> commit lookups (60s), also for a repo that was just re-seeded, so the
# set may briefly see the previous run's content: nudge the controller until it sees the fresh repo.
settle() {  # settle SET CMD...
  local set="$1" i; shift
  for i in $(seq 1 12); do
    am_wait 15 "$@" && return 0
    kubectl -n argocd annotate applicationset "$set" argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null
  done
  return 1
}

all_four() {
  local a
  for a in studio-render studio-thumbnails studio-captions studio-shared; do kubectl -n argocd get application "$a" >/dev/null || return 1; done
}
settle studio all_four || { echo "setup: the four Applications were not generated"; exit 1; }
for s in render thumbnails captions; do
  am_wait_app "studio-$s" sync=Synced health=Healthy --timeout 150 || { echo "setup: studio-$s did not become healthy"; exit 1; }
done
am_wait_app studio-shared sync=Synced health=Healthy --timeout 120 \
  || { echo "setup: studio-shared did not appear"; exit 1; }
am_setup_assert "ConfigMap studio-defaults deployed" kubectl -n studio get configmap studio-defaults
am_workspace_clone studio-platform
