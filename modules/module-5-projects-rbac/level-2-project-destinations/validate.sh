#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=rx-dispatch
PROJ=clinic
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"

[ "$(am_app "$APP" '{.spec.project}')" = "$PROJ" ] \
  || am_fail "Application '$APP' no longer belongs to the '$PROJ' project"
dest_ns="$(am_app "$APP" '{.spec.destination.namespace}')"
[ "$dest_ns" = "pharmacy" ] \
  || am_fail "Application '$APP' deploys to namespace '${dest_ns:-<none>}', but the pharmacy system lives in 'pharmacy'"
am_ok "Application '$APP' still belongs to project '$PROJ' and targets namespace pharmacy"

proj="$(kubectl -n argocd get appproject "$PROJ" -o json 2>/dev/null)" \
  || am_fail "AppProject '$PROJ' does not exist"
printf '%s' "$proj" | jq -r '.spec.destinations[]? | .namespace // ""' >"$AM_TMP/ns.txt"
matches() {
  "$AM_PYTHON" - "$AM_TMP/ns.txt" "$1" <<'PY'
import fnmatch, sys
pats = [l.strip() for l in open(sys.argv[1]) if l.strip()]
ok = any(fnmatch.fnmatchcase(sys.argv[2], p) for p in pats if not p.startswith("!"))
sys.exit(0 if ok else 1)
PY
}
matches pharmacy || am_fail "Project '$PROJ' does not list namespace 'pharmacy' as a destination"
for ns in kube-system argocd; do
  matches "$ns" && am_fail "Project '$PROJ' allows deployments into '$ns' as well, far more than this team needs"
done
am_ok "Project '$PROJ' allows namespace pharmacy, but not the cluster's own namespaces"

am_require_app_at_head "$APP" rx-dispatch
am_wait_rollout deploy/rx-dispatch pharmacy
body="$(am_http http://rx-dispatch.pharmacy pharmacy)" || am_fail "Service rx-dispatch in namespace pharmacy does not answer"
[ "$body" = "rx-dispatch v4.1" ] || am_fail "Service rx-dispatch answers '$body'"
am_pass "rx-dispatch runs in namespace pharmacy inside its own project"
