#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=shiftboard
NS=shiftboard
fails=0
bad() { echo "❌ $*"; fails=$((fails+1)); }
good() { am_ok "$*"; }

am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"
head="$(am_repo_head shiftboard)"

# ── Release state: the head commit went out through a clean sync ────────────────
sync="$(am_app_sync "$APP")"; health="$(am_app_health "$APP")"; rev="$(am_app_rev "$APP")"
op="$(am_app_op "$APP")"; oprev="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
if [ "$op" != Succeeded ] || [ "$oprev" != "$head" ]; then
  bad "Release: the last sync of '$APP' is ${op:-missing} at ${oprev:0:7} (main is at ${head:0:7}): $(am_app "$APP" '{.status.operationState.message}')"
else
  good "Release: the last sync of '$APP' Succeeded at ${head:0:7}"
fi
[ "$sync" = Synced ] && [ "$rev" = "$head" ] && [ "$health" = Healthy ] \
  || bad "Release: '$APP' is $sync/$health at ${rev:0:7} (expected Synced/Healthy at ${head:0:7})"

app_json="$(am_app_json "$APP")"
hook() { echo "$app_json" | jq -r --arg n "$1" --arg t "$2" '[.status.operationState.syncResult.resources[]? | select(.kind=="Job" and .name==$n and .hookType==$t and .hookPhase=="Succeeded")] | length'; }
[ "$(hook rota-migrate PreSync)" != 0 ] || [ "$(hook rota-migrate Sync)" != 0 ] \
  || bad "Migration: the last sync did not run the migration Job rota-migrate to completion"
[ "$(hook shiftboard-smoke PostSync)" != 0 ] \
  || bad "Smoke test: the last sync did not run a passing PostSync test (Job shiftboard-smoke)"
[ "$(kubectl -n $NS get cm schema-version -o jsonpath='{.data.version}' 2>/dev/null)" = v7 ] \
  || bad "Migration: ConfigMap schema-version does not record v7: migration 0007 did not run"
rest="$(kubectl -n $NS get shiftpolicies.rostering.argomissions.io weekend -o jsonpath='{.spec.restDays}' 2>/dev/null)"
[ "$rest" = 2 ] || bad "Policy: ShiftPolicy 'weekend' has restDays '${rest:-<unset>}' in namespace $NS (release v7 says 2)"
body="$(am_http http://shiftboard.$NS $NS 2 2>/dev/null)"
[ "$body" = "shiftboard v7" ] || bad "Service: shiftboard answers '${body:-nothing}' instead of 'shiftboard v7'"

# ── The CRD Application ──────────────────────────────────────────────────────────
if am_app_exists rota-crds; then
  chead="$head"
  if [ "$(am_app_sync rota-crds)" != Synced ] || [ "$(am_app_rev rota-crds)" != "$chead" ] || [ "$(am_app_health rota-crds)" != Healthy ]; then
    bad "Policy: Application rota-crds is $(am_app_sync rota-crds)/$(am_app_health rota-crds) at $(am_app_rev rota-crds | cut -c1-7): the ShiftPolicy CRD is behind the release"
  fi
  kubectl get crd shiftpolicies.rostering.argomissions.io -o json | jq -e '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.restDays' >/dev/null 2>&1 \
    || bad "Policy: the ShiftPolicy CRD in the cluster does not know the field restDays that release v7 uses"
  [ "$(am_app rota-crds '{.spec.syncPolicy.automated}')" != "" ] \
    || bad "Policy: Application rota-crds waits for a manual sync, so every release that changes the CRD depends on someone remembering to do it first"
else
  bad "Policy: Application rota-crds is gone: nothing keeps the ShiftPolicy CRD in step with Git"
fi

# ── What Git says about the next release ─────────────────────────────────────────
work="$AM_TMP/repo"
am_repo_checkout shiftboard "$work" >/dev/null 2>&1 || am_fail "cannot clone shiftboard"
am_yaml_docs_json "$work/deploy" >"$AM_TMP/docs.json"
"$AM_PYTHON" - "$AM_TMP/docs.json" <<'PY' || fails=$((fails+1))
import json, sys
docs = json.load(open(sys.argv[1]))
RANK = {"PreSync": 0, "Sync": 1, "PostSync": 2}
bad = []

def ann(d):
    return (d.get("metadata") or {}).get("annotations") or {}

def key(d):
    a = ann(d)
    wave = int(str(a.get("argocd.argoproj.io/sync-wave", "0")).strip() or 0)
    hook = a.get("argocd.argoproj.io/hook")
    if hook:
        ranks = [RANK[h.strip()] for h in hook.split(",") if h.strip() in RANK]
        return (min(ranks), wave) if ranks else None
    return (1, wave)

def find(kind, name=None):
    return [d for d in docs if d.get("kind") == kind and (name is None or d["metadata"]["name"] == name)]

jobs = find("Job", "rota-migrate")
if not jobs:
    bad.append("Migration: Job rota-migrate is no longer in Git")
else:
    j = jobs[0]; jk = key(j)
    pol = ann(j).get("argocd.argoproj.io/hook-delete-policy", "")
    if jk is None or jk[0] == 2:
        bad.append("Migration: Job rota-migrate in Git is not a hook that runs before the release")
    elif not ({p.strip() for p in pol.split(",")} & {"BeforeHookCreation", "HookSucceeded"}):
        bad.append("Migration: in Git, a finished run of Job rota-migrate stays in the cluster, so the next change to it is rejected as immutable")
    for kind in ("ServiceAccount", "Role", "RoleBinding"):
        objs = find(kind, "rota-migrator")
        if not objs:
            bad.append(f"Migration: {kind} rota-migrator is no longer in Git"); continue
        k = key(objs[0])
        if jk is not None and (k is None or not k < jk):
            bad.append(f"Migration: in Git, {kind} rota-migrator is not applied strictly before Job rota-migrate runs "
                       f"(phase/wave {k} vs {jk}); a permission change in the same release is too late for the migration")
    dk = [key(d) for d in find("Deployment", "shiftboard")]
    if jk is not None and (not dk or not dk[0] > jk):
        bad.append("Migration: in Git, Deployment shiftboard does not roll out strictly after the migration Job")

smoke = find("Job", "shiftboard-smoke")
if not smoke:
    bad.append("Smoke test: Job shiftboard-smoke is no longer in Git")
else:
    c = (smoke[0]["spec"]["template"]["spec"]["containers"][0])
    cmd = " ".join((c.get("command") or []) + (c.get("args") or []))
    svcs = {d["metadata"]["name"] for d in find("Service")}
    if "curl" not in cmd:
        bad.append("Smoke test: the test in Git no longer calls the service")
    elif any(x in cmd for x in ("|| true", "exit 0", ";true", "; true")):
        bad.append("Smoke test: the test in Git swallows its own errors: a test that cannot fail tests nothing")
    else:
        import re
        m = re.search(r"https?://([a-z0-9-]+)", cmd)
        if not m or m.group(1) not in svcs:
            bad.append("Smoke test: the test in Git calls a host that is not a Service of this release (%s)" % (m.group(1) if m else "none"))
for b in bad:
    print("❌ " + b)
if bad:
    sys.exit(1)
print("✅ Git: migration cleanup, RBAC-before-migration and the smoke test are all in order")
PY

[ "$fails" = 0 ] || { echo "   $fails problem(s) left"; exit 1; }
am_pass "release v7 is live; the next release will not trip over the same things"
