#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=payroll-engine
am_require_app_at_head "$APP" payroll-engine

head="$(am_repo_head payroll-engine)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}"
[ "$(am_app_op "$APP")" = Succeeded ] || am_fail "The last sync operation of '$APP' did not succeed"

[ "$(kubectl -n payroll get job ledger-migrate -o jsonpath='{.status.succeeded}' 2>/dev/null)" = 1 ] \
  || am_fail "Job ledger-migrate did not complete in namespace payroll"
[ "$(kubectl -n payroll get configmap schema-version -o jsonpath='{.data.version}' 2>/dev/null)" = v4.1 ] \
  || am_fail "ConfigMap schema-version in namespace payroll does not record v4.1: the migration did not run"
am_ok "The v4.1 migration completed"

# The Git content must make this reproducible: the migrator's Role and RoleBinding have to be applied before
# the migration Job runs, and the Job has to finish before the Deployment rolls out.
work="$AM_TMP/repo"
am_repo_checkout payroll-engine "$work" || am_fail "Cannot clone payroll-engine"
am_yaml_docs_json "$work/deploy" >"$AM_TMP/docs.json"
"$AM_PYTHON" - "$AM_TMP/docs.json" <<'PY' || exit 1
import json, sys
docs = json.load(open(sys.argv[1]))
RANK = {"PreSync": 0, "Sync": 1, "PostSync": 2}

def key(d):
    ann = (d.get("metadata") or {}).get("annotations") or {}
    wave = int(str(ann.get("argocd.argoproj.io/sync-wave", "0")).strip() or 0)
    hook = ann.get("argocd.argoproj.io/hook")
    if hook:
        ranks = [RANK[h.strip()] for h in hook.split(",") if h.strip() in RANK]
        return (min(ranks), wave) if ranks else None
    return (1, wave)

def find(kind, name=None):
    return [d for d in docs if d.get("kind") == kind and (name is None or d["metadata"]["name"] == name)]

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

jobs = find("Job", "ledger-migrate")
if not jobs: fail("Job ledger-migrate is no longer in Git")
jk = key(jobs[0])
if jk is None: fail("Job ledger-migrate in Git has no runnable hook phase")
for kind in ("Role", "RoleBinding"):
    objs = find(kind, "migrator")
    if not objs: fail(f"{kind} migrator is no longer in Git")
    k = key(objs[0])
    if k is None or not k < jk:
        fail(f"In Git, {kind} migrator is not applied strictly before Job ledger-migrate runs (phase/wave {k} vs {jk}): "
             "the next permission change will hit the same wall")
dk = [key(d) for d in find("Deployment", "payroll-engine")]
if not dk or not dk[0] > jk:
    fail("In Git, Deployment payroll-engine does not roll out strictly after the migration Job has finished")
print("✅ Git orders the RBAC objects before the migration and the migration before the rollout")
PY

body="$(am_http http://payroll-engine.payroll payroll)" || am_fail "Service payroll-engine in namespace payroll does not answer"
[ "$body" = "payroll-engine v4.1" ] || am_fail "Service payroll-engine answers '$body'"
am_pass "payroll-engine v4.1 is live, migrated, and ordered correctly in Git"
