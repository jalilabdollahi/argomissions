#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=nightly-etl
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# Git is the truth: the manifests stay out of the repo
am_repo_checkout nightly-etl "$AM_TMP/git" || am_fail "cannot clone repo nightly-etl"
n="$(am_yaml_docs_json "$AM_TMP/git/deploy" | jq 'length')"
[ "$n" = 0 ] || am_fail "Git folder deploy/ defines $n objects again; the workloads were meant to leave this repo"
am_ok "Git folder deploy/ defines no objects"

am_app_sync_ok() { [ "$(am_app_sync "$APP")" = Synced ]; }
am_wait 60 am_app_sync_ok || am_fail "Application '$APP' is $(am_app_sync "$APP") (expected Synced)"
head="$(am_repo_head nightly-etl)"
[ "$(am_app_rev "$APP")" = "$head" ] || am_fail "Application '$APP' is at $(am_app_rev "$APP" | cut -c1-7), repo is at ${head:0:7}"
synced_at_head() { [ "$(am_app "$APP" '{.status.operationState.phase}')" = Succeeded ] \
  && [ "$(am_app "$APP" '{.status.operationState.syncResult.revision}')" = "$head" ]; }
am_wait 30 synced_at_head \
  || { am_app_conditions "$APP" > "$AM_TMP/cond.txt"; am_fail "No sync of '$APP' has completed at ${head:0:7}" "$AM_TMP/cond.txt"; }
am_ok "Application '$APP' is Synced; the sync of ${head:0:7} succeeded"

left="$(kubectl -n etl get deploy,svc,cm -o name 2>/dev/null | grep -v 'configmap/kube-root-ca.crt' | tr '\n' ' ')"
[ -z "$left" ] || am_fail "Namespace etl still has: $left"
am_ok "Namespace etl holds none of the old objects"
am_pass "nightly-etl is empty and in sync with Git"
