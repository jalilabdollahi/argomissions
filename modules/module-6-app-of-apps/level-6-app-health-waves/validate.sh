#!/bin/bash
set -uo pipefail
source "$AM_LIB"

ROOT=beacon-root
am_require_app_at_head "$ROOT" beacon-fleet

# 1. Argo CD must assess Application health, and report it faithfully. Ask Argo CD's own resource-override
#    engine, with the live argocd-cm, what it makes of an Application in each state.
kubectl -n argocd get configmap argocd-cm -o yaml >"$AM_TMP/cm.yaml" 2>/dev/null || am_fail "Cannot read ConfigMap argocd-cm"
am_app_json beacon-db >"$AM_TMP/app.json"
for st in Healthy Progressing Degraded; do
  jq --arg st "$st" '.status.health={status:$st}' "$AM_TMP/app.json" >"$AM_TMP/probe-$st.json"
  got="$(am_argocd admin settings resource-overrides health "$AM_TMP/probe-$st.json" --argocd-cm-path "$AM_TMP/cm.yaml" 2>&1 | sed -n 's/^STATUS: //p')"
  if [ "$got" != "$st" ]; then
    am_fail "Argo CD does not assess the health of an Application resource: one whose status is $st is not reported as $st"
  fi
done
am_ok "Argo CD reports the health of Application resources (Healthy, Progressing, Degraded)"

# 2. The tree: children owned by the root, still ordered in Git, Synced and Healthy.
work="$AM_TMP/repo"
am_repo_checkout beacon-fleet "$work" || am_fail "Cannot clone beacon-fleet"
am_yaml_get "$work/apps/db.yaml" metadata.annotations >"$AM_TMP/ann.json"
dw="$(jq -r '.["argocd.argoproj.io/sync-wave"] // empty' "$AM_TMP/ann.json")"
am_yaml_get "$work/apps/api.yaml" metadata.annotations >"$AM_TMP/ann.json"
aw="$(jq -r '.["argocd.argoproj.io/sync-wave"] // empty' "$AM_TMP/ann.json")"
[[ "$dw" =~ ^-?[0-9]+$ && "$aw" =~ ^-?[0-9]+$ && "$dw" -lt "$aw" ]] \
  || am_fail "In Git, beacon-db is no longer in an earlier sync-wave than beacon-api"
am_ok "Git still orders beacon-db (wave $dw) before beacon-api (wave $aw)"

for app in beacon-db beacon-api; do
  am_require_app_at_head "$app" beacon-fleet
  tid="$(am_app "$app" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}')"
  case "$tid" in "$ROOT:argoproj.io/Application:argocd/$app") ;; *) am_fail "Application '$app' is not managed by '$ROOT'" ;; esac
done

# 3. Proof of the order on the current instance of the platform.
db_ready="$(kubectl -n beacon-data get deploy beacon-db -o jsonpath='{.status.conditions[?(@.type=="Available")].lastTransitionTime}' 2>/dev/null)"
api_created="$(am_app beacon-api '{.metadata.creationTimestamp}')"
[ -n "$db_ready" ] || am_fail "Deployment beacon-db in namespace beacon-data is not available"
[[ ! "$api_created" < "$db_ready" ]] \
  || am_fail "Application beacon-api was created at $api_created, before beacon-db's workload became available at $db_ready: the platform has not been brought up in order since the waves were fixed"
am_ok "beacon-api was created ($api_created) after beacon-db's workload was available ($db_ready)"

body="$(am_http http://beacon-db.beacon-data beacon-data)" || am_fail "Service beacon-db in namespace beacon-data does not answer"
[ "$body" = "beacon-db v3.1" ] || am_fail "Service beacon-db answers '$body'"
body="$(am_http http://beacon-api.beacon-edge beacon-edge)" || am_fail "Service beacon-api in namespace beacon-edge does not answer"
[ "$body" = "beacon-api v3.1" ] || am_fail "Service beacon-api answers '$body'"
am_pass "The Beacon platform comes up in order, and Argo CD enforces it"
