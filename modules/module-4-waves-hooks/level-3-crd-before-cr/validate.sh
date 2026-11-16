#!/bin/bash
set -uo pipefail
source "$AM_LIB"

CRD=probes.sensors.argomissions.io

for app in sensor-crds sensor-hub; do
  am_require_app_at_head "$app" sensor-hub
  head="$(am_repo_head sensor-hub)"
  synced="$(am_app "$app" '{.status.operationState.syncResult.revision}')"
  [ "$synced" = "$head" ] || am_fail "The last sync of '$app' deployed ${synced:0:7}, but main is at ${head:0:7}"
  [ "$(am_app_op "$app")" = Succeeded ] || am_fail "The last sync operation of '$app' is $(am_app_op "$app"), not Succeeded"
done
am_ok "Both Applications finished a successful sync of the head commit"

kubectl get crd "$CRD" >/dev/null 2>&1 || am_fail "CustomResourceDefinition $CRD does not exist on the cluster"
am_app_json sensor-crds | jq -e --arg n "$CRD" '[.status.resources[]? | select(.kind=="CustomResourceDefinition" and .name==$n and .status=="Synced")] | length == 1' >/dev/null \
  || am_fail "CRD $CRD is not a Synced resource of Application sensor-crds"
am_ok "The CRD is managed by Application sensor-crds"

[ "$(kubectl get crd "$CRD" -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null)" = True ] \
  || am_fail "CRD $CRD is not Established"

kubectl -n sensors get probes.sensors.argomissions.io boiler-temp >/dev/null 2>&1 || am_fail "Probe boiler-temp does not exist in namespace sensors"
am_app_json sensor-hub | jq -e '[.status.resources[]? | select(.kind=="Probe" and .name=="boiler-temp" and .status=="Synced")] | length == 1' >/dev/null \
  || am_fail "Probe boiler-temp is not a Synced resource of Application sensor-hub"
am_ok "Probe boiler-temp exists and is managed by Application sensor-hub"
interval="$(kubectl -n sensors get probes.sensors.argomissions.io boiler-temp -o jsonpath='{.spec.interval}')"
[ "$interval" = 30s ] || am_fail "Probe boiler-temp has interval '$interval' instead of the one in Git"
am_pass "The Probe CRD and its first instance are both live and owned by Argo CD"
