#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=query-service
PROJECT=search-platform

am_require_app_at_head "$APP" query-service

project="$(kubectl -n argocd get appproject "$PROJECT" -o json 2>/dev/null || echo '{}')"
[ "$(echo "$project" | jq '.spec.orphanedResources != null')" = true ] \
  || am_fail "Project $PROJECT does not monitor orphaned resources"
[ "$(echo "$project" | jq '.spec.orphanedResources.warn // true')" = true ] \
  || am_fail "Project $PROJECT monitors orphaned resources but does not warn about them"
am_ok "Project $PROJECT monitors orphaned resources and warns"

kubectl -n search get secret search-tls-manual >/dev/null 2>&1 \
  || am_fail "Secret search-tls-manual (documented exception, runbook SEC-114) is gone"
if kubectl -n search get deployment legacy-indexer >/dev/null 2>&1; then
  am_fail "Deployment legacy-indexer, which no Application owns, still runs in namespace search"
fi
am_ok "The stray workload is gone, the TLS Secret is still there"

# The ignore rules must cover the Secret and must not be able to hide the workload that had to go.
echo "$project" | jq -c '.spec.orphanedResources.ignore // []' >"$AM_TMP/ignore.json"
"$AM_PYTHON" - "$AM_TMP/ignore.json" <<'PY' || exit 1
import fnmatch, json, sys
rules = json.load(open(sys.argv[1]))
def match(rule, group, kind, name):
    return all(fnmatch.fnmatchcase(v, rule.get(k, "*") or "*") for k, v in (("group", group), ("kind", kind), ("name", name)))
if not any(match(r, "", "Secret", "search-tls-manual") for r in rules):
    print("❌ The orphan rules of project search-platform do not exclude the Secret search-tls-manual"); sys.exit(1)
if any(match(r, "apps", "Deployment", "legacy-indexer") for r in rules):
    print("❌ The ignore rules of project search-platform are so broad that they would hide an orphaned Deployment"); sys.exit(1)
PY
am_ok "The exception is a narrow rule on the project"

# Let Argo CD re-evaluate the namespace with the current project settings, then read its verdict.
am_app_refresh "$APP" hard
clean() {
  [ -z "$(am_app_json "$APP" | jq -r '.status.conditions[]? | select(.type=="OrphanedResourceWarning") | .message')" ] || return 1
  am_argocd app resources "$APP" --orphaned >"$AM_TMP/orphans.txt" 2>&1 || return 1
  ! grep -q ' Yes$' "$AM_TMP/orphans.txt"
}
am_wait 60 clean || am_fail "Argo CD still reports orphaned resources for '$APP'" "$AM_TMP/orphans.txt"
am_ok "Argo CD reports no orphaned resources"
am_pass "Nothing unowned is left, and the documented exception is declared"
