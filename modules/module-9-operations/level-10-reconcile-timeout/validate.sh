#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=lobby-board
NS=lobby
DEFAULT_S=180

# duration string (Go style) -> seconds; empty = Argo CD default (3m)
secs() {
  "$AM_PYTHON" - "$1" "$DEFAULT_S" <<'PY'
import re, sys
v = sys.argv[1].strip()
if not v:
    print(sys.argv[2]); sys.exit(0)
total, rest = 0.0, v
units = {"h": 3600, "m": 60, "s": 1, "ms": 0.001}
for m in re.finditer(r"([0-9.]+)(ms|h|m|s)", v):
    total += float(m.group(1)) * units[m.group(2)]
if not re.fullmatch(r"(?:[0-9.]+(?:ms|h|m|s))+", v):
    print(-1); sys.exit(0)
print(int(total))
PY
}

cm_val="$(kubectl -n argocd get configmap argocd-cm -o jsonpath='{.data.timeout\.reconciliation}' 2>/dev/null || true)"
cm_s="$(secs "$cm_val")"
{ [ "$cm_s" -ge 30 ] && [ "$cm_s" -le 600 ]; } \
  || am_fail "argocd-cm sets timeout.reconciliation to '${cm_val:-<unset>}': Argo CD should look at Git between every 30 seconds and every 10 minutes"
am_ok "argocd-cm timeout.reconciliation is '${cm_val:-<default>}'"

ctl="$(kubectl -n argocd exec argocd-application-controller-0 -- printenv ARGOCD_RECONCILIATION_TIMEOUT 2>/dev/null || true)"
rs="$(kubectl -n argocd exec deploy/argocd-repo-server -c argocd-repo-server -- printenv ARGOCD_RECONCILIATION_TIMEOUT 2>/dev/null || true)"
[ "$(secs "$ctl")" = "$cm_s" ] \
  || am_fail "The application controller is running with a reconciliation timeout of '${ctl:-<default>}', not the configured '${cm_val:-<default>}'"
[ "$(secs "$rs")" = "$cm_s" ] \
  || am_fail "The repo-server is running with a reconciliation timeout of '${rs:-<default>}', not the configured '${cm_val:-<default>}'"
am_ok "The application controller and the repo-server both run with the configured timeout"

am_require_app_at_head "$APP" lobby-board
am_require_synced_by_argo "$APP" lobby-board

body="$(am_http http://lobby-board.$NS "$NS")" || am_fail "Service lobby-board in namespace $NS does not answer"
[ "$body" = "lobby-board v1.1" ] || am_fail "Service lobby-board answers '$body'"
am_pass "Argo CD polls Git on a sane schedule and lobby-board v1.1 is live"
