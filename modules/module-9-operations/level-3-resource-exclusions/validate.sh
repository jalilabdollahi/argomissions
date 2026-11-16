#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=lexicon-site
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# what argocd-cm excludes: does a rule still hide ConfigMaps from the in-cluster destination, or is it so wide
# that it hides everything?
verdict="$(kubectl -n argocd get configmap argocd-cm -o json | "$AM_PYTHON" -c '
import json, sys, yaml
data = json.load(sys.stdin).get("data", {})
raw = data.get("resource.exclusions")
rules = yaml.safe_load(raw) if raw else []
if rules is None: rules = []
def match(vals, x): return any(v in ("*", x) for v in (vals or ["*"]))
cm = ep = False
for r in rules:
    groups, kinds, clusters = r.get("apiGroups"), r.get("kinds"), r.get("clusters")
    in_cluster = any(c in ("*", "https://kubernetes.default.svc", "in-cluster") for c in (clusters or ["*"])) or any(c == "*" for c in (clusters or []))
    if not in_cluster: continue
    if match(groups, "") and match(kinds, "ConfigMap"): cm = True
    if match(groups, "apps") and match(kinds, "Deployment"): ep = True
print("configmap" if cm else ("all" if ep else "ok"))
')"
[ "$verdict" != all ] || am_fail "argocd-cm excludes workloads as well: Argo CD no longer sees Deployments"
[ "$verdict" != configmap ] || am_fail "argocd-cm still excludes ConfigMaps from the in-cluster destination (resource.exclusions)"
am_ok "ConfigMaps are no longer excluded"
if kubectl -n argocd get configmap argocd-cm -o json | jq -e '.data["resource.exclusions"] == null' >/dev/null; then
  am_ok "argocd-cm has no custom resource.exclusions (Argo CD's defaults apply)"
else
  kubectl -n argocd get configmap argocd-cm -o json | jq -r '.data["resource.exclusions"]' | grep -q 'EndpointSlice' \
    || am_fail "resource.exclusions no longer hides EndpointSlices (noisy kinds were meant to stay excluded)"
  am_ok "noisy kinds (EndpointSlice) stay excluded"
fi

am_app_refresh "$APP" normal
sleep 3
am_app_conditions "$APP" | grep -q ExcludedResourceWarning \
  && am_fail "Application '$APP' still reports: $(am_app_conditions "$APP" | grep ExcludedResourceWarning | head -1)"
am_require_app_at_head "$APP" lexicon-site

tracking="$(am_jsonpath configmap/lexicon-pages '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' lexicon)"
[ -n "$tracking" ] || am_fail "ConfigMap lexicon-pages in namespace lexicon is missing or not managed by Argo CD"
am_ok "ConfigMap lexicon-pages is managed by Argo CD"
am_wait_rollout deploy/lexicon-site lexicon 90s

body="$(am_http http://lexicon-site.lexicon lexicon)" || am_fail "Service lexicon-site in namespace lexicon does not answer"
[ "$body" = "lexicon-site v3.1" ] || am_fail "Service lexicon-site answers '$body'"
am_pass "lexicon-site is live, its ConfigMap delivered by Argo CD"
