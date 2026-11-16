#!/bin/bash
set -uo pipefail
source "$AM_LIB"

ROOT=tracing-root
PROJECT=tracing-team
am_require_app_at_head "$ROOT" tracing-gitops

# The project must be maintained by the root (so it comes from Git), not created by hand.
am_app_json "$ROOT" | jq -e --arg p "$PROJECT" '.status.resources[]? | select(.kind=="AppProject" and .name==$p)' >/dev/null \
  || am_fail "AppProject '$PROJECT' is not among the objects '$ROOT' maintains"
am_ok "AppProject '$PROJECT' is maintained by $ROOT"

for child in trace-collector trace-query; do
  am_app_exists "$child" || am_fail "Application '$child' does not exist"
  [ "$(am_app "$child" '{.spec.project}')" = "$PROJECT" ] \
    || am_fail "Application '$child' no longer belongs to project '$PROJECT' (it runs in '$(am_app "$child" '{.spec.project}')')"
done

# The project has to keep its boundaries.
kubectl -n argocd get appproject "$PROJECT" -o json >"$AM_TMP/proj.json" 2>/dev/null || am_fail "AppProject '$PROJECT' does not exist in the cluster"
jq -e '(.spec.sourceRepos // []) | index("*") | not' "$AM_TMP/proj.json" >/dev/null || am_fail "Project '$PROJECT' accepts every source repository"
jq -e '[.spec.destinations[]? | select(.namespace=="*" or .server=="*")] | length == 0' "$AM_TMP/proj.json" >/dev/null \
  || am_fail "Project '$PROJECT' accepts every destination"
am_ok "Project '$PROJECT' is limited to its repository and namespaces"

# Git: the project is applied strictly before the children that use it, so a fresh bootstrap works first time.
work="$AM_TMP/repo"
am_repo_checkout tracing-gitops "$work" || am_fail "Cannot clone tracing-gitops"
am_yaml_docs_json "$work/apps" >"$AM_TMP/docs.json"
"$AM_PYTHON" - "$AM_TMP/docs.json" "$PROJECT" <<'PY' || exit 1
import json, sys
docs = json.load(open(sys.argv[1])); proj = sys.argv[2]
def wave(d):
    a = (d.get("metadata") or {}).get("annotations") or {}
    return int(str(a.get("argocd.argoproj.io/sync-wave", "0")).strip() or 0)
projs = [d for d in docs if d.get("kind") == "AppProject" and d["metadata"]["name"] == proj]
if not projs:
    print("❌ The root's folder in Git does not contain AppProject " + proj); sys.exit(1)
apps = [d for d in docs if d.get("kind") == "Application" and (d.get("spec") or {}).get("project") == proj]
if len(apps) < 2:
    print("❌ Fewer than two Applications in Git use project " + proj); sys.exit(1)
pw = wave(projs[0])
late = [a["metadata"]["name"] for a in apps if not pw < wave(a)]
if late:
    print("❌ In Git, AppProject %s is not applied strictly before %s (a fresh cluster would create them in the same wave)" % (proj, ", ".join(late)))
    sys.exit(1)
print("✅ Git applies AppProject %s before the Applications that use it" % proj)
PY

for pair in trace-collector:tracing-collector:"trace-collector v5.1" trace-query:tracing-query:"trace-query v2.0"; do
  IFS=: read -r child ns want <<<"$pair"
  am_require_app_at_head "$child" tracing-gitops
  am_app_conditions "$child" | grep -q InvalidSpecError && am_fail "Application '$child' still has an InvalidSpecError condition"
  body="$(am_http "http://$child.$ns" "$ns")" || am_fail "Service $child in namespace $ns does not answer"
  [ "$body" = "$want" ] || am_fail "Service $child answers '$body'"
done
am_pass "the tracing project is created by the root before its children, and both services are live"
