#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=ops-statusboard
NS=boards

am_require_app_at_head "$APP" statusboard-config
am_require_synced_by_argo "$APP" statusboard-config

# Synced must be earned, not faked by hiding the whole spec from the comparison.
am_app_json "$APP" | jq -r '.spec.ignoreDifferences[]? | (.jsonPointers[]?, .jqPathExpressions[]?, .managedFieldsManagers[]?)' >"$AM_TMP/ignored.txt" 2>/dev/null || true
while IFS= read -r p; do
  case "$p" in
    /spec|/spec/|/spec/panels|/spec/panels/*/name|/spec/panels/*/query|.spec|.spec.panels|".spec.panels[]"|.spec.title|/spec/title)
      am_fail "ignoreDifferences hides '$p' from the comparison: more than the defaulted field is being ignored" ;;
  esac
done <"$AM_TMP/ignored.txt"

# The board itself must be the one from Git: three panels, managed by Argo CD.
board="$(kubectl -n "$NS" get statusboard oncall -o json 2>/dev/null || true)"
[ -n "$board" ] || am_fail "StatusBoard oncall does not exist in namespace $NS"
[ "$(jq -r '.metadata.annotations["argocd.argoproj.io/tracking-id"] // ""' <<<"$board" | wc -c)" -gt 1 ] \
  || am_fail "StatusBoard oncall is not managed by Argo CD"
panels="$(jq -r '[.spec.panels[].name] | join(",")' <<<"$board")"
[ "$panels" = "checkout-latency,error-budget,queue-depth" ] || am_fail "StatusBoard oncall has panels '$panels'"
am_ok "StatusBoard oncall has its three panels, managed by Argo CD"

am_repo_checkout statusboard-config "$AM_TMP/git" >/dev/null 2>&1 || am_fail "cannot clone statusboard-config"
am_yaml_docs_json "$AM_TMP/git/deploy" >"$AM_TMP/docs.json"
[ "$(jq -r '[.[] | select(.kind=="StatusBoard")] | length' "$AM_TMP/docs.json")" = 1 ] \
  || am_fail "statusboard-config no longer defines the StatusBoard"
am_pass "ops-statusboard is Synced: the defaulted field no longer shows as a difference"
