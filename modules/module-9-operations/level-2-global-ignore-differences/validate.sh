#!/bin/bash
set -uo pipefail
source "$AM_LIB"

SVCS="ingest rollup gateway"

# somebody else's controller: it must still be there, writing
[ "$(kubectl -n complyd-system get deploy complyd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)" = 1 ] \
  || am_fail "The security team's scanner (complyd in namespace complyd-system) is not running: the conflict was removed, not resolved"
am_ok "the compliance scanner keeps running"

for s in $SVCS; do
  app="tallyline-$s"
  am_app_exists "$app" || am_fail "Application '$app' does not exist in namespace argocd"
  ign="$(am_app "$app" '{.spec.ignoreDifferences}')"
  [ -z "$ign" ] || am_fail "Application '$app' carries its own ignoreDifferences: the scanner will stamp the next service too, and every Application would have to be edited"
done
am_ok "no Application carries a private ignoreDifferences"

# the cluster-wide setting must exist and must not be a blanket "ignore everything"
am_argocd_cm_ok() {
  kubectl -n argocd get configmap argocd-cm -o json | "$AM_PYTHON" -c '
import json, sys, yaml
data = json.load(sys.stdin).get("data", {})
found = False
broad_ptr = {"", "/", "/spec", "/metadata", "/metadata/labels", "/spec/template", "/spec/template/spec", "/spec/replicas", "/status"}
broad_jq = {".", ".spec", ".metadata", ".metadata.labels", ".spec.template", ".spec.template.spec", ".spec.replicas", ".status"}
for key, val in data.items():
    if key.startswith("resource.customizations.ignoreDifferences."):
        docs = [yaml.safe_load(val) or {}]
    elif key == "resource.customizations":
        docs = [((v or {}).get("ignoreDifferences") or {}) for v in (yaml.safe_load(val) or {}).values() if isinstance(v, dict)]
    else:
        continue
    for d in docs:
        if not d:
            continue
        found = True
        if set(d.get("jsonPointers") or []) & broad_ptr or set(x.strip() for x in d.get("jqPathExpressions") or []) & broad_jq:
            print("broad"); sys.exit(0)
print("ok" if found else "none")
'
}
verdict="$(am_argocd_cm_ok)"
[ "$verdict" != none ] || am_fail "argocd-cm has no cluster-wide ignoreDifferences customization: every Application is still compared field by field"
[ "$verdict" != broad ] || am_fail "The cluster-wide ignoreDifferences in argocd-cm is so wide that real changes to the Deployments (spec, metadata) would be hidden as well"
am_ok "argocd-cm carries a cluster-wide, narrow ignoreDifferences customization"

for s in $SVCS; do am_app_refresh "tallyline-$s" normal; done
all_synced() {
  local s
  for s in $SVCS; do [ "$(am_app_sync "tallyline-$s")" = Synced ] || return 1; done
}
am_wait 75 all_synced || am_fail "Not every Application is Synced: $(for s in $SVCS; do printf 'tallyline-%s=%s ' "$s" "$(am_app_sync "tallyline-$s")"; done)"
for s in $SVCS; do am_require_app_at_head "tallyline-$s" tallyline; done

# the mutation must still be happening, and the Applications must stay Synced through it
l1="$(am_jsonpath deploy/tallyline-ingest '{.metadata.labels.complyd\.argomissions\.io/scan}' tallyline-ingest)"
sleep 13
l2="$(am_jsonpath deploy/tallyline-ingest '{.metadata.labels.complyd\.argomissions\.io/scan}' tallyline-ingest)"
[ -n "$l2" ] && [ "$l1" != "$l2" ] \
  || am_fail "The live Deployments are no longer being modified by the scanner (scan label '$l1' -> '$l2')"
am_ok "the live Deployment keeps changing (scan $l1 -> $l2)"
for s in $SVCS; do am_app_refresh "tallyline-$s" normal; done
sleep 4
all_synced || am_fail "An Application went OutOfSync when the scanner wrote again"
am_ok "all three Applications stay Synced while the scanner writes"

for s in $SVCS; do
  body="$(am_http "http://tallyline-$s.tallyline-$s" "tallyline-$s")" || am_fail "Service tallyline-$s does not answer"
  [ "$body" = "tallyline-$s v4.2" ] || am_fail "Service tallyline-$s answers '$body'"
done
am_pass "the whole tallyline pipeline stays Synced while the scanner keeps stamping"
