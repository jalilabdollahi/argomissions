#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=claims-intake
PROJ=claims
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"

[ "$(am_app "$APP" '{.spec.project}')" = "$PROJ" ] \
  || am_fail "Application '$APP' no longer belongs to the '$PROJ' team project"
repo="$(am_app "$APP" '{.spec.source.repoURL}')"
[ "${repo%.git}" = "$(am_repo_url intake-gateway | sed 's/\.git$//')" ] \
  || am_fail "Application '$APP' reads from '$repo', not the intake-gateway repo"
am_ok "Application '$APP' still belongs to project '$PROJ' and reads intake-gateway"

proj="$(kubectl -n argocd get appproject "$PROJ" -o json 2>/dev/null)" \
  || am_fail "AppProject '$PROJ' does not exist"
printf '%s' "$proj" | jq -r '.spec.sourceRepos[]?' >"$AM_TMP/sources.txt"
permits() {
  "$AM_PYTHON" - "$AM_TMP/sources.txt" "$1" <<'PY'
import fnmatch, sys
pats = [l.strip() for l in open(sys.argv[1]) if l.strip()]
url = sys.argv[2].removesuffix(".git")
ok = any(fnmatch.fnmatchcase(url, p.removesuffix(".git")) for p in pats if not p.startswith("!"))
sys.exit(0 if ok else 1)
PY
}
permits "$(am_repo_url intake-gateway)" || am_fail "Project '$PROJ' does not list the intake-gateway repo as a source"
permits "$(am_repo_url payroll-secrets)" \
  && am_fail "Project '$PROJ' accepts any repository, even one that has nothing to do with claims"
am_ok "Project '$PROJ' accepts intake-gateway, and only a limited set of repositories"

am_require_app_at_head "$APP" intake-gateway
am_wait_rollout deploy/claims-intake claims
body="$(am_http http://claims-intake.claims claims)" || am_fail "Service claims-intake in namespace claims does not answer"
[ "$body" = "claims-intake v2.3" ] || am_fail "Service claims-intake answers '$body'"
am_pass "claims-intake is deployed through its own project, with a scoped source list"
