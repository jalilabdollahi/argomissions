#!/bin/bash
set -uo pipefail
source "$AM_LIB"

ROOT=tariff-root
FIN=resources-finalizer.argocd.argoproj.io
# 1. The retired service is really gone: no Application, no workload tracked by it, nothing answering.
am_app_exists tariff-legacy && am_fail "Application 'tariff-legacy' exists again: the service was meant to stay retired"
orphans="$(kubectl get deploy,svc,pods,cm -A -o json 2>/dev/null \
  | jq -r '.items[] | select((.metadata.annotations["argocd.argoproj.io/tracking-id"] // "") | startswith("tariff-legacy:")) | "\(.kind)/\(.metadata.name)"')"
[ -z "$orphans" ] || am_fail "The retired tariff-legacy workload still runs in namespace tariff-old: $(echo $orphans | tr '\n' ' ')"
kubectl -n tariff-old get deploy tariff-legacy >/dev/null 2>&1 && am_fail "Deployment tariff-legacy still exists in namespace tariff-old"
am_ok "Nothing of tariff-legacy is left in the cluster"

# 2. The next retirement must cascade: every child Application in Git carries the finalizer, and so does the live one.
work="$AM_TMP/repo"
am_repo_checkout tariff-gitops "$work" || am_fail "Cannot clone tariff-gitops"
am_yaml_docs_json "$work/apps" >"$AM_TMP/docs.json"
"$AM_PYTHON" - "$AM_TMP/docs.json" "$FIN" <<'PY' || exit 1
import json, sys
docs = json.load(open(sys.argv[1])); fin = sys.argv[2]
apps = [d for d in docs if d.get("kind") == "Application"]
names = sorted(a["metadata"]["name"] for a in apps)
if "tariff-api" not in names:
    print("❌ Application tariff-api is no longer in Git"); sys.exit(1)
if "tariff-legacy" in names:
    print("❌ Application tariff-legacy is back in the root's folder in Git"); sys.exit(1)
bad = [a["metadata"]["name"] for a in apps if fin not in ((a.get("metadata") or {}).get("finalizers") or [])]
if bad:
    print("❌ In Git, Application(s) %s would leave their workloads behind when removed again (no cascade on delete)" % ", ".join(bad)); sys.exit(1)
print("✅ Every Application in Git cascades its workloads when it is removed")
PY
am_app "tariff-api" '{.metadata.finalizers}' | grep -q "$FIN" || am_fail "The live Application 'tariff-api' does not carry the finalizer yet"

am_require_app_at_head "$ROOT" tariff-gitops
[ "$(am_app_sync tariff-api)" = Synced ] && [ "$(am_app_health tariff-api)" = Healthy ] \
  || am_fail "Application 'tariff-api' is $(am_app_sync tariff-api)/$(am_app_health tariff-api) (expected Synced/Healthy)"
am_ok "tariff-root is at head and tariff-api is Synced and Healthy"

body="$(am_http http://tariff-api.tariff-live tariff-live)" || am_fail "Service tariff-api in namespace tariff-live does not answer"
[ "$body" = "tariff-api v4.0" ] || am_fail "Service tariff-api answers '$body'"
am_pass "tariff-legacy is gone for good and future retirements clean up after themselves"
