#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=fleet-tracker
am_require_app_at_head "$APP" fleet-tracker

head="$(am_repo_head fleet-tracker)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
phase="$(am_app_op "$APP")"
[ "$phase" = Succeeded ] || am_fail "The last sync operation of '$APP' is in phase ${phase:-unknown}, not Succeeded"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}: the current head was never shipped by a sync"
am_ok "The sync of ${head:0:7} completed (Succeeded)"

[ "$(am_ready_replicas tracker-api fleet)" -ge 1 ] || am_fail "Deployment tracker-api in namespace fleet has no ready pod"
[ "$(am_ready_replicas tracker-web fleet)" -ge 1 ] || am_fail "Deployment tracker-web in namespace fleet has no ready pod"
am_ok "tracker-api and tracker-web are ready"

body="$(am_http http://tracker-web.fleet fleet)" || am_fail "Service tracker-web in namespace fleet does not answer"
[ "$body" = "fleet-tracker v1.4" ] || am_fail "Service tracker-web answers '$body'"
am_pass "fleet-tracker v1.4 is live"
