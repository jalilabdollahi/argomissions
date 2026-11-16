#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=profile-svc
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# somebody else's controller: it must still be there, writing
[ "$(kubectl -n profiles-finops get deploy cost-stamper -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)" = 1 ] \
  || am_fail "The finance platform's controller (cost-stamper in namespace profiles-finops) is not running: the conflict was removed, not resolved"
am_ok "the cost controller keeps running"

am_require_app_at_head "$APP" profile-svc
am_wait_rollout deploy/profile-svc profiles 60s

# the mutation must still be happening, and the Application must stay Synced through it
l1="$(am_jsonpath deploy/profile-svc '{.metadata.labels.cost-center}' profiles)"
sleep 13
l2="$(am_jsonpath deploy/profile-svc '{.metadata.labels.cost-center}' profiles)"
[ -n "$l2" ] && [ "$l1" != "$l2" ] \
  || am_fail "The live Deployment is no longer being modified by the controller (cost-center label '$l1' → '$l2')"
am_ok "the live Deployment keeps changing (cost-center $l1 → $l2)"
[ "$(am_app_sync "$APP")" = Synced ] || am_fail "Application '$APP' went $(am_app_sync "$APP") when the controller wrote again"
am_require_app_at_head "$APP" profile-svc

body="$(am_http http://profile-svc.profiles profiles)" || am_fail "Service profile-svc in namespace profiles does not answer"
[ "$body" = "profile-svc v2.3" ] || am_fail "Service profile-svc answers '$body'"
am_pass "profile-svc stays Synced while the cost controller keeps stamping it"
