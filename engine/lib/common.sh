# shellcheck shell=bash
# ArgoMissions helper library — sourced by every level's setup.sh / validate.sh / solve.sh / tests:
#
#   source "$AM_LIB"
#
# Environment provided by the engine (and by scripts/test_levels.py):
#   LEVEL_DIR   absolute path of the level directory (mission.yaml, assets/ ...)
#   SANDBOX     absolute path of the player's workspace (repos are cloned here)
#   AM_LIB      this file
#   AM_ROOT     repository root
#   AM_PYTHON   python3 that has PyYAML
#   KUBECONFIG  the game's own kubeconfig (.am-shared/kubeconfig)
#   ARGOCD_OPTS points the argocd CLI at the game's own config (.am-shared/argocd/config)
# The working directory is $SANDBOX.

if [ -z "${AM_ROOT:-}" ]; then
  AM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
: "${AM_PYTHON:=python3}"
: "${KUBECONFIG:=$AM_ROOT/.am-shared/kubeconfig}"
: "${ARGOCD_OPTS:=--config $AM_ROOT/.am-shared/argocd/config}"
: "${SANDBOX:=$PWD}"
export AM_ROOT AM_PYTHON KUBECONFIG ARGOCD_OPTS SANDBOX AM_GIT_PORT AM_ARGOCD_PORT

ARGO_NS=argocd
: "${AM_GIT_PORT:=3300}" "${AM_ARGOCD_PORT:=9080}"
AM_GIT_HOST="http://localhost:$AM_GIT_PORT"   # what the player (and these scripts) use
AM_GIT_INCLUSTER="http://gitea.gitea.svc.cluster.local:3000"   # what Argo CD uses
AM_GIT_USER=player
AM_GIT_PASS=argomissions
AM_ORG=platform
AM_ARGOCD_ADDR="localhost:$AM_ARGOCD_PORT"
AM_ARGOCD_PASSWORD=argomissions
export GIT_TERMINAL_PROMPT=0
export ARGO_NS AM_GIT_HOST AM_GIT_INCLUSTER AM_GIT_USER AM_GIT_PASS AM_ORG AM_ARGOCD_ADDR AM_ARGOCD_PASSWORD

# ── output ───────────────────────────────────────────────────────────────────
am_info() { echo "🔍 $*"; }
am_ok()   { echo "✅ $*"; }
am_warn() { echo "⚠️  $*"; }
# am_fail "message" [file-with-details]  → prints and exits 1
am_fail() {
  echo "❌ $1"
  if [ -n "${2:-}" ] && [ -s "$2" ]; then sed 's/^/   │ /' "$2" | head -n 25; fi
  exit 1
}
am_pass() { echo "✅ ${1:-Mission complete!}"; exit 0; }
# am_setup_assert "what should be true" CMD...  → for setup.sh: exit 1 if the scenario was not reached
am_setup_assert() {
  local what="$1"; shift
  "$@" >/dev/null 2>&1 || { echo "setup: scenario not reached: $what"; exit 1; }
}

# ── temp files (auto-removed on exit) ────────────────────────────────────────
AM_TMP="$(mktemp -d "${TMPDIR:-/tmp}/argomissions.XXXXXX")"
trap 'rm -rf "$AM_TMP"' EXIT

# am_wait TIMEOUT_SECONDS CMD... → retry CMD every 2s until it succeeds; returns 1 on timeout
am_wait() {
  local timeout="$1" start; shift
  start=$(date +%s)
  until "$@" >/dev/null 2>&1; do
    [ $(( $(date +%s) - start )) -ge "$timeout" ] && return 1
    sleep 2
  done
}

# ── Git / Gitea ──────────────────────────────────────────────────────────────
# am_repo_url NAME       → URL Argo CD uses (in-cluster)
am_repo_url() { echo "$AM_GIT_INCLUSTER/$AM_ORG/$1.git"; }
# am_repo_host_url NAME  → URL the player clones from
am_repo_host_url() { echo "$AM_GIT_HOST/$AM_ORG/$1.git"; }
_am_push_url() { echo "http://$AM_GIT_USER:$AM_GIT_PASS@localhost:$AM_GIT_PORT/$AM_ORG/$1.git"; }
_am_git() { git -c user.name="Platform Bot" -c user.email="bot@platform.local" -c init.defaultBranch=main \
               -c advice.detachedHead=false "$@"; }

# am_gitea METHOD PATH [JSON] → Gitea API call (prints the response body, fails on HTTP errors)
am_gitea() {
  local method="$1" api="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -fsS -X "$method" -u "$AM_GIT_USER:$AM_GIT_PASS" -H 'Content-Type: application/json' -d "$body" "$AM_GIT_HOST/api/v1$api"
  else
    curl -fsS -X "$method" -u "$AM_GIT_USER:$AM_GIT_PASS" "$AM_GIT_HOST/api/v1$api"
  fi
}

# am_repo_create NAME [private]  → (re)create an empty repo in the platform org
am_repo_create() {
  local name="$1" private=false
  [ "${2:-}" = private ] && private=true
  am_gitea DELETE "/repos/$AM_ORG/$name" >/dev/null 2>&1 || true
  am_gitea POST "/orgs/$AM_ORG/repos" "{\"name\":\"$name\",\"private\":$private,\"default_branch\":\"main\",\"auto_init\":false}" >/dev/null
}

# am_repo_seed NAME SRC_DIR [MESSAGE]  → (re)create repo NAME with SRC_DIR as one commit on main.
#   PRIVATE=1 makes the repo private.
am_repo_seed() {
  local name="$1" src="$2" msg="${3:-Initial import}" w
  am_repo_create "$name" ${PRIVATE:+private}
  w="$AM_TMP/seed-$name-$RANDOM"
  mkdir -p "$w"
  cp -R "$src/." "$w/"
  (cd "$w" && _am_git init -q && _am_git add -A && _am_git commit -q -m "$msg" \
    && _am_git push -q "$(_am_push_url "$name")" HEAD:refs/heads/main) \
    || { echo "am_repo_seed: push to $name failed" >&2; return 1; }
}

# am_repo_commit NAME SRC_DIR MESSAGE  → one commit that writes SRC_DIR's files over the tree.
#   DELETE="path1 path2"  removes paths in the same commit.   BRANCH=x  commits to branch x (default main).
am_repo_commit() {
  local name="$1" src="$2" msg="$3" branch="${BRANCH:-main}" w p
  w="$AM_TMP/commit-$name-$RANDOM"
  _am_git clone -q --branch "$branch" "$(_am_push_url "$name")" "$w" || return 1
  [ -n "$src" ] && [ -d "$src" ] && cp -R "$src/." "$w/"
  for p in ${DELETE:-}; do (cd "$w" && git rm -q -r --ignore-unmatch "$p"); done
  (cd "$w" && _am_git add -A && _am_git commit -q -m "$msg" && _am_git push -q origin "HEAD:refs/heads/$branch") \
    || { echo "am_repo_commit: commit to $name failed" >&2; return 1; }
}

# am_repo_branch NAME NEW_BRANCH [FROM_REF]  → create a branch
am_repo_branch() {
  local w="$AM_TMP/branch-$1-$RANDOM"
  _am_git clone -q "$(_am_push_url "$1")" "$w" && (cd "$w" && _am_git push -q origin "${3:-HEAD}:refs/heads/$2")
}
# am_repo_delete_branch NAME BRANCH
am_repo_delete_branch() { _am_git push -q "$(_am_push_url "$1")" ":refs/heads/$2"; }
# am_repo_tag NAME TAG [REF]  → create a lightweight tag
am_repo_tag() {
  local w="$AM_TMP/tag-$1-$RANDOM"
  _am_git clone -q "$(_am_push_url "$1")" "$w" && (cd "$w" && _am_git tag "$2" "${3:-HEAD}" && _am_git push -q origin "refs/tags/$2")
}

# am_repo_head NAME [BRANCH]  → commit SHA of the branch head (empty if missing)
am_repo_head() {
  git ls-remote "$(_am_push_url "$1")" "refs/heads/${2:-main}" 2>/dev/null | awk '{print $1}'
}
# am_repo_checkout NAME DIR [BRANCH]  → full clone into DIR (read-only inspection by validators)
am_repo_checkout() {
  rm -rf "$2"
  _am_git clone -q --branch "${3:-main}" "$(_am_push_url "$1")" "$2"
}

# am_workspace_clone NAME [DIR]  → clone into the player's workspace, ready to commit and push
am_workspace_clone() {
  local dir="$SANDBOX/${2:-$1}"
  rm -rf "$dir"
  git clone -q "$(_am_push_url "$1")" "$dir"
  if [ -z "$(git -C "$dir" config user.email || true)" ]; then
    git -C "$dir" config user.name "ArgoMissions Player"
    git -C "$dir" config user.email "player@argomissions.local"
  fi
}

# am_player_push DIR MESSAGE  → commit everything in a workspace clone and push (for solve.sh / tests)
am_player_push() {
  (cd "$1" && git add -A && git commit -q -m "$2" && git push -q origin HEAD) \
    || { echo "am_player_push: nothing committed or push failed in $1" >&2; return 1; }
}

# ── Argo CD ──────────────────────────────────────────────────────────────────
# am_argocd ARGS...  → the argocd CLI against the game's Argo CD (logs in again if the session expired)
am_argocd() {
  # shellcheck disable=SC2086
  if ! argocd $ARGOCD_OPTS account get-user-info -o json 2>/dev/null | grep -q '"loggedIn": *true'; then
    # shellcheck disable=SC2086
    argocd $ARGOCD_OPTS login "$AM_ARGOCD_ADDR" --plaintext --username admin --password "$AM_ARGOCD_PASSWORD" \
      --name argomissions >/dev/null 2>&1
  fi
  # shellcheck disable=SC2086
  argocd $ARGOCD_OPTS "$@"
}

# am_app APP JSONPATH  → field of an Application in namespace argocd (empty if missing)
am_app() { kubectl -n "$ARGO_NS" get application "$1" -o "jsonpath=$2" 2>/dev/null || true; }
am_app_exists() { kubectl -n "$ARGO_NS" get application "$1" >/dev/null 2>&1; }
am_app_sync()   { am_app "$1" '{.status.sync.status}'; }
am_app_health() { am_app "$1" '{.status.health.status}'; }
am_app_rev()    { am_app "$1" '{.status.sync.revision}'; }
am_app_op()     { am_app "$1" '{.status.operationState.phase}'; }
am_app_json()   { kubectl -n "$ARGO_NS" get application "$1" -o json 2>/dev/null || echo '{}'; }
# am_app_conditions APP  → "TYPE: message" lines from .status.conditions
am_app_conditions() { am_app_json "$1" | jq -r '.status.conditions[]? | "\(.type): \(.message)"'; }

# am_app_apply FILE  → create Applications (replacing stale ones with the same name, without cascade)
am_app_apply() {
  local n
  for n in $(kubectl apply --dry-run=client -f "$1" -o name 2>/dev/null | sed 's#.*/##'); do
    kubectl -n "$ARGO_NS" patch application "$n" --type json -p '[{"op":"remove","path":"/metadata/finalizers"}]' >/dev/null 2>&1 || true
    kubectl -n "$ARGO_NS" delete application "$n" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  done
  kubectl apply -f "$1" >/dev/null
}

# am_app_refresh APP [normal|hard]  → ask Argo CD to re-read Git now
am_app_refresh() {
  kubectl -n "$ARGO_NS" annotate application "$1" "argocd.argoproj.io/refresh=${2:-hard}" --overwrite >/dev/null
}

# am_app_sync_now APP [REVISION]  → start a sync operation, like the Sync button: the operation carries
#   the Application's spec.syncPolicy.syncOptions (a raw `operation` patch would not). PRUNE=1 prunes.
am_app_sync_now() {
  local patch
  patch="$(am_app_json "$1" | jq -c --arg rev "${2:-}" --arg prune "${PRUNE:-}" '{operation: {initiatedBy: {username: "admin"},
      sync: ({syncStrategy: {hook: {}}}
             + (if (.spec.syncPolicy.syncOptions // []) != [] then {syncOptions: .spec.syncPolicy.syncOptions} else {} end)
             + (if $prune != "" then {prune: true} else {} end)
             + (if $rev != "" then {revision: $rev} else {} end))}}')"
  kubectl -n "$ARGO_NS" patch application "$1" --type merge -p "$patch" >/dev/null
}

# am_wait_app APP KEY=VALUE... [--timeout N]
#   keys: sync (Synced|OutOfSync|Unknown), health (Healthy|Degraded|Progressing|Missing|...),
#         op (Succeeded|Failed|Error|Running), rev (commit SHA), cond (substring of any condition message),
#         opmsg (substring of the operation message), oprev (SHA the last sync operation deployed)
am_wait_app() {
  local app="$1" timeout=180 start k v ok; shift
  local checks=()
  while [ $# -gt 0 ]; do
    if [ "$1" = --timeout ]; then timeout="$2"; shift 2; else checks+=("$1"); shift; fi
  done
  start=$(date +%s)
  while true; do
    ok=1
    for c in "${checks[@]}"; do
      k="${c%%=*}"; v="${c#*=}"
      case "$k" in
        sync)   [ "$(am_app_sync "$app")" = "$v" ] || ok=0 ;;
        health) [ "$(am_app_health "$app")" = "$v" ] || ok=0 ;;
        op)     [ "$(am_app_op "$app")" = "$v" ] || ok=0 ;;
        rev)    [ "$(am_app_rev "$app")" = "$v" ] || ok=0 ;;
        cond)   am_app_conditions "$app" | grep -qF -- "$v" || ok=0 ;;
        opmsg)  am_app "$app" '{.status.operationState.message}' | grep -qF -- "$v" || ok=0 ;;
        oprev)  [ "$(am_app "$app" '{.status.operationState.syncResult.revision}')" = "$v" ] || ok=0 ;;
        *) echo "am_wait_app: unknown key $k" >&2; return 2 ;;
      esac
    done
    [ "$ok" = 1 ] && return 0
    [ $(( $(date +%s) - start )) -ge "$timeout" ] && {
      echo "am_wait_app $app ${checks[*]}: timed out (sync=$(am_app_sync "$app") health=$(am_app_health "$app") op=$(am_app_op "$app"))" >&2
      return 1
    }
    sleep 2
  done
}

# am_require_app_at_head APP REPO [BRANCH]  → validator: Application Synced + Healthy at the branch head
#   (multi-source apps: REPO's head must be one of .status.sync.revisions)
am_require_app_at_head() {
  local app="$1" repo="$2" branch="${3:-main}" sync health rev head
  am_app_exists "$app" || am_fail "Application '$app' does not exist in namespace argocd"
  sync="$(am_app_sync "$app")"; health="$(am_app_health "$app")"; rev="$(am_app_rev "$app")"
  head="$(am_repo_head "$repo" "$branch")"
  [ "$sync" = Synced ] || am_fail "Application '$app' is ${sync:-Unknown} (expected Synced)"
  if [ -z "$rev" ]; then   # multi-source Application: one revision per source in .status.sync.revisions
    if [ -n "$head" ] && am_app "$app" '{.status.sync.revisions[*]}' | tr ' ' '\n' | grep -qx "$head"; then
      rev="$head"
    else
      rev="$(am_app "$app" '{.status.sync.revisions[*]}')"
    fi
  fi
  [ -n "$head" ] && [ "$rev" = "$head" ] \
    || am_fail "Application '$app' is synced to ${rev:0:7}, but $repo/$branch is at ${head:0:7}"
  [ "$health" = Healthy ] || am_fail "Application '$app' health is ${health:-Unknown} (expected Healthy)"
  am_ok "Application '$app' is Synced and Healthy at $repo@${head:0:7}"
}

# ── Kubernetes ───────────────────────────────────────────────────────────────
# am_jsonpath KIND/NAME JSONPATH NS → value (empty if missing)
am_jsonpath() { kubectl get "$1" -n "$3" -o "jsonpath=$2" 2>/dev/null || true; }
# am_wait_rollout KIND/NAME NS [TIMEOUT]  → validator check
am_wait_rollout() {
  kubectl rollout status "$1" -n "$2" --timeout="${3:-60s}" >"$AM_TMP/rollout.txt" 2>&1 \
    || am_fail "$1 in namespace $2 is not ready" "$AM_TMP/rollout.txt"
  am_ok "$1 in namespace $2 is ready"
}
# am_ready_replicas DEPLOYMENT NS → number of ready replicas (0 if missing)
am_ready_replicas() {
  local n; n="$(am_jsonpath "deploy/$1" '{.status.readyReplicas}' "$2")"; echo "${n:-0}"
}
# am_endpoints_count SERVICE NS → number of ready endpoint addresses
am_endpoints_count() {
  kubectl get endpointslices -n "$2" -l "kubernetes.io/service-name=$1" -o json 2>/dev/null \
    | jq '[.items[].endpoints[]? | select(.conditions.ready != false)] | length' 2>/dev/null || echo 0
}
# am_http URL NS [TRIES] → curl URL from a one-shot pod in namespace NS, prints the body
am_http() {
  local tries="${3:-5}" n out=""
  for n in $(seq 1 "$tries"); do
    if out="$(_am_http_once "$1" "$2")"; then printf '%s\n' "$out"; return 0; fi
    [ "$n" -lt "$tries" ] && sleep 3
  done
  printf '%s\n' "$out" >&2
  return 1
}
_am_http_once() {
  local name="am-probe-$RANDOM" ns="$2" phase="" i rc=1
  kubectl run "$name" -n "$ns" --image=curlimages/curl:8.10.1 --image-pull-policy=IfNotPresent --restart=Never \
    --labels=argomissions.io/probe=true --command -- curl -fsS --max-time 5 "$1" >/dev/null 2>&1 || return 1
  for i in $(seq 1 40); do
    phase="$(kubectl get pod "$name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    { [ "$phase" = Succeeded ] || [ "$phase" = Failed ]; } && break
    sleep 1
  done
  [ "$phase" = Succeeded ] && rc=0
  kubectl logs "pod/$name" -n "$ns" 2>/dev/null
  kubectl delete "pod/$name" -n "$ns" --now --wait=false >/dev/null 2>&1 || true
  return $rc
}

# ── YAML ─────────────────────────────────────────────────────────────────────
# am_yaml_get FILE dotted.path [DOC_INDEX] → value as JSON (null if missing). Lists: a.b.0.c
am_yaml_get() {
  "$AM_PYTHON" - "$1" "$2" "${3:-0}" <<'PY'
import json, sys, yaml
try:
    docs = [d for d in yaml.safe_load_all(open(sys.argv[1], encoding="utf-8")) if d is not None]
except Exception:
    print("null"); sys.exit(0)
idx = int(sys.argv[3])
node = docs[idx] if idx < len(docs) else None
for part in [p for p in sys.argv[2].split(".") if p]:
    if isinstance(node, list) and part.isdigit() and int(part) < len(node):
        node = node[int(part)]
    elif isinstance(node, dict) and part in node:
        node = node[part]
    else:
        node = None
        break
print(json.dumps(node))
PY
}
# am_yaml_docs_json FILE|DIR → every YAML document under FILE/DIR as one JSON array
am_yaml_docs_json() {
  "$AM_PYTHON" - "$1" <<'PY'
import json, pathlib, sys, yaml
p = pathlib.Path(sys.argv[1])
files = sorted(p.rglob("*.y*ml")) if p.is_dir() else [p]
out = []
for f in files:
    try:
        out += [d for d in yaml.safe_load_all(f.read_text(encoding="utf-8")) if isinstance(d, dict)]
    except Exception:
        pass
print(json.dumps(out))
PY
}

# am_require_synced_by_argo APP REPO [BRANCH]  → validator: the last sync OPERATION deployed the branch head
#   (stronger than am_require_app_at_head: a kubectl patch that happens to match Git leaves the app
#   "Synced at head" without any sync having run; this proves Argo CD itself applied that commit)
am_require_synced_by_argo() {
  local app="$1" repo="$2" branch="${3:-main}" head op_rev phase
  head="$(am_repo_head "$repo" "$branch")"
  op_rev="$(am_app "$app" '{.status.operationState.syncResult.revision}')"
  phase="$(am_app_op "$app")"
  [ "$phase" = Succeeded ] || am_fail "The last sync of '$app' is ${phase:-missing} (expected a Succeeded sync)"
  [ -n "$head" ] && [ "$op_rev" = "$head" ] \
    || am_fail "The last sync of '$app' deployed ${op_rev:0:7}, but $repo/$branch is at ${head:0:7}"
  am_ok "The last sync of '$app' deployed $repo@${head:0:7}"
}
