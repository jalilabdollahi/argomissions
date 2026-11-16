#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=radar-agent
PROJ=radar
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"
[ "$(am_app "$APP" '{.spec.project}')" = "$PROJ" ] \
  || am_fail "Application '$APP' no longer belongs to the '$PROJ' project"

proj="$(kubectl -n argocd get appproject "$PROJ" -o json 2>/dev/null)" || am_fail "AppProject '$PROJ' does not exist"
wild="$(printf '%s' "$proj" | jq -r '[.spec.clusterResourceWhitelist[]? | select(.group=="*" or .kind=="*")] | length')"
[ "$wild" = 0 ] || am_fail "Project '$PROJ' lets its Applications create any kind of cluster-wide object"
stray="$(printf '%s' "$proj" | jq -r '[.spec.clusterResourceWhitelist[]? | select(.group != "rbac.authorization.k8s.io" or (.kind != "ClusterRole" and .kind != "ClusterRoleBinding"))] | length')"
[ "$stray" = 0 ] || am_fail "Project '$PROJ' allows cluster-wide kinds the radar agent does not use"
for kind in ClusterRole ClusterRoleBinding; do
  n="$(printf '%s' "$proj" | jq -r --arg k "$kind" '[.spec.clusterResourceWhitelist[]? | select(.group=="rbac.authorization.k8s.io" and .kind==$k)] | length')"
  [ "$n" -ge 1 ] || am_fail "Project '$PROJ' still refuses a cluster-wide object the repo contains"
done
am_ok "Project '$PROJ' allows exactly the RBAC cluster objects the repo needs"

am_require_app_at_head "$APP" radar-agent
am_require_synced_by_argo "$APP" radar-agent
for k in clusterrole clusterrolebinding; do
  t="$(kubectl get "$k" radar-node-reader -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null || true)"
  [ -n "$t" ] || am_fail "$k radar-node-reader does not exist or is not managed by Argo CD"
done
am_ok "ClusterRole and ClusterRoleBinding radar-node-reader are managed by Argo CD"
am_wait_rollout deploy/radar-agent radar
body="$(am_http http://radar-agent.radar radar)" || am_fail "Service radar-agent in namespace radar does not answer"
[ "$body" = "radar-agent v0.9" ] || am_fail "Service radar-agent answers '$body'"
am_pass "radar-agent is deployed with the cluster permissions it needs, nothing more"
