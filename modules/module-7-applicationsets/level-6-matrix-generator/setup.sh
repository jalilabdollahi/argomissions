#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed mesh-services "$LEVEL_DIR/repo" "invoicer and mailer charts"
# A re-seeded repo gets new commit SHAs, but Argo CD caches branch -> commit lookups (in Redis) for a minute:
# start every run from an empty cache so that the generators and Applications see this run's repo.
kubectl -n argocd exec deploy/argocd-redis -c redis -- sh -c 'redis-cli -a "$REDIS_PASSWORD" flushall' >/dev/null 2>&1 || true
cp "$LEVEL_DIR/assets/appset.yaml" "$SANDBOX/mesh-appset.yaml"
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

broken() {
  kubectl -n argocd get applicationset mesh -o json | jq -e \
    '[.status.conditions[]? | select(.type=="ErrorOccurred" and .status=="True" and (.message | contains("duplicate name")))] | length > 0'
}
settle mesh broken || { echo "setup: the duplicate-name error did not appear"; exit 1; }
am_setup_assert "no Applications" bash -c '[ -z "$(kubectl -n argocd get applications -o name)" ]'
