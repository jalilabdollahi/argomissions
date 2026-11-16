#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=inventory-sync
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"

src_path="$(am_app "$APP" '{.spec.source.path}')"
case "${src_path%/}" in
  kustomize/overlays/prod) ;;
  *) am_fail "Application '$APP' deploys '${src_path:-<repo root>}', which is not the production environment" ;;
esac
am_ok "Application '$APP' deploys the production overlay"

am_require_app_at_head "$APP" inventory-sync

# the shared base must still be a neutral, single-replica base that the staging overlay builds on
am_repo_checkout inventory-sync "$AM_TMP/co" || am_fail "cannot clone inventory-sync"
base_replicas="$(kubectl kustomize "$AM_TMP/co/kustomize/base" 2>/dev/null | "$AM_PYTHON" -c '
import sys, yaml
for d in yaml.safe_load_all(sys.stdin):
    if d and d.get("kind") == "Deployment": print(d["spec"]["replicas"])')"
[ "$base_replicas" = 1 ] || am_fail "The shared base in Git was changed (it renders $base_replicas replicas) - environments should differ in their overlays"

[ "$(am_jsonpath deploy/inventory-sync '{.spec.replicas}' inventory)" = 3 ] \
  || am_fail "Deployment inventory-sync has $(am_jsonpath deploy/inventory-sync '{.spec.replicas}' inventory) replicas, production needs 3"
[ "$(am_ready_replicas inventory-sync inventory)" = 3 ] || am_fail "Deployment inventory-sync does not have 3 ready pods"
am_ok "Deployment inventory-sync runs 3 replicas"

body="$(am_http http://inventory-sync.inventory inventory)" || am_fail "Service inventory-sync in namespace inventory does not answer"
[ "$body" = "inventory-sync prod" ] || am_fail "Service inventory-sync answers '$body'"
am_pass "inventory-sync runs the production overlay"
