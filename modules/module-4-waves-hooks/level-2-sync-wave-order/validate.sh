#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=shipping-ui
NS=shipping

am_require_app_at_head "$APP" shipping-ui

head="$(am_repo_head shipping-ui)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}"
op="$(am_app_op "$APP")"
[ "$op" = Succeeded ] || am_fail "The last sync operation of '$APP' is ${op:-unknown}, not Succeeded"
am_ok "The last sync at the head commit Succeeded"

# Git: the ConfigMap must not be applied after the Deployment that needs it.
am_repo_checkout shipping-ui "$AM_TMP/git" >/dev/null 2>&1 || am_fail "cannot clone shipping-ui"
am_yaml_docs_json "$AM_TMP/git/deploy" >"$AM_TMP/docs.json"
res="$(jq -r '
  def wave: ((.metadata.annotations // {})["argocd.argoproj.io/sync-wave"] // "0") | (tonumber? // 0);
  (map(select(.kind=="ConfigMap" and .metadata.name=="shipping-ui-config"))[0]) as $c
  | (map(select(.kind=="Deployment" and .metadata.name=="shipping-ui"))[0]) as $d
  | if $c == null or $d == null then "missing"
    elif ($c|wave) <= ($d|wave) then "ok" else "late" end' "$AM_TMP/docs.json")"
case "$res" in
  ok) am_ok "In Git, the ConfigMap is not applied after the Deployment" ;;
  missing) am_fail "The ConfigMap or the Deployment is missing from the repo" ;;
  *) am_fail "In Git, the Deployment is rolled out in an earlier sync wave than the ConfigMap it reads, and waits for it to be healthy" ;;
esac

[ "$(am_ready_replicas shipping-ui "$NS")" -ge 1 ] || am_fail "Deployment shipping-ui in namespace $NS has no ready pod"
body="$(am_http http://shipping-ui.$NS "$NS")" || am_fail "Service shipping-ui in namespace $NS does not answer"
[ "$body" = "shipping-ui carrier=dhl" ] || am_fail "Service shipping-ui answers '$body'"
am_pass "shipping-ui reads its configuration and is live"
