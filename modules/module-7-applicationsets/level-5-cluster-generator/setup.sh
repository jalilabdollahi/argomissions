#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed quota-service "$LEVEL_DIR/repo" "quota-api v3"
# A re-seeded repo gets new commit SHAs, but Argo CD caches branch -> commit lookups (in Redis) for a minute:
# start every run from an empty cache so that the generators and Applications see this run's repo.
kubectl -n argocd exec deploy/argocd-redis -c redis -- sh -c 'redis-cli -a "$REDIS_PASSWORD" flushall' >/dev/null 2>&1 || true
# `staging` is an alias of the cluster we run in, registered through its own DNS name and the
# application controller's service account token (so the player needs no extra credentials).
token="$(kubectl -n argocd create token argocd-application-controller --duration=24h)"
sed "s|__TOKEN__|$token|" "$LEVEL_DIR/assets/cluster-secret.yaml" | kubectl apply -f - >/dev/null
registered() { am_argocd cluster list | grep -q '^https://kubernetes.default.svc.cluster.local .*staging'; }
am_wait 60 registered || { echo "setup: cluster staging not registered"; exit 1; }

kubectl apply -f "$LEVEL_DIR/assets/appset.yaml" >/dev/null
generated() {
  kubectl -n argocd get applicationset quota-fleet -o json | jq -e \
    '[.status.conditions[]? | select(.type=="ResourcesUpToDate" and .status=="True")] | length > 0'
}
am_wait 60 generated || { echo "setup: the ApplicationSet did not reconcile"; exit 1; }
sleep 5
am_setup_assert "no Applications" bash -c '[ -z "$(kubectl -n argocd get applications -o name)" ]'
