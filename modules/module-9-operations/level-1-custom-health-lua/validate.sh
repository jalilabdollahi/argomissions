#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=vaultline
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

[ "$(am_app_sync "$APP")" = Synced ] || am_fail "Application '$APP' is $(am_app_sync "$APP") (expected Synced)"
rev="$(am_app_rev "$APP")"; head="$(am_repo_head vaultline-backups)"
[ "$rev" = "$head" ] || am_fail "Application '$APP' is synced to ${rev:0:7}, but vaultline-backups/main is at ${head:0:7}"
am_ok "Application '$APP' is Synced at the head of main"

# GitOps-honest: the operator's status is the truth; it must not have been rewritten to make Argo CD green
phase() { kubectl -n vaultline get backups.vaultline.argomissions.io "$1" -o jsonpath='{.status.phase}' 2>/dev/null || true; }
[ "$(phase nightly-ledger)" = Failed ] \
  || am_fail "Backup nightly-ledger no longer reports the phase the operator wrote (now '$(phase nightly-ledger)'): the failure was hidden, not surfaced"
[ "$(phase weekly-archive)" = Done ] && [ "$(phase hourly-journal)" = Running ] \
  || am_fail "The status of the Backups was changed by hand; the operator's status must stay as it is"
am_ok "the Backups still carry the status the operator wrote"

am_app_refresh "$APP" normal
res_health() {
  am_argocd app get "$APP" -o json 2>/dev/null \
    | jq -r --arg n "$1" '.status.resources[]? | select(.kind=="Backup" and .name==$n) | .health.status // "none"'
}
check_all() {
  [ "$(res_health nightly-ledger)" = Degraded ] && [ "$(res_health weekly-archive)" = Healthy ] \
    && [ "$(res_health hourly-journal)" = Progressing ]
}
am_wait 45 check_all || am_fail "Argo CD reports nightly-ledger=$(res_health nightly-ledger), weekly-archive=$(res_health weekly-archive), hourly-journal=$(res_health hourly-journal) (expected the health to follow each Backup's phase: Failed, Done, Running)"
am_ok "Argo CD reports nightly-ledger Degraded, weekly-archive Healthy, hourly-journal Progressing"

health="$(am_app_health "$APP")"
[ "$health" = Degraded ] || am_fail "Application '$APP' health is $health although a Backup has failed (expected Degraded)"
am_pass "Argo CD now tells the truth about the Backups (application Degraded)"
