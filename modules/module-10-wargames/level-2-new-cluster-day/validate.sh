#!/bin/bash
set -uo pipefail
source "$AM_LIB"

bad=0
bad() { echo "❌ $1"; bad=$((bad + 1)); }

ROOT=tidewater-root
REPO=tidewater-gitops
URL="$(am_repo_url $REPO)"

# ── the repository: private, read through the machine user ──────────────────
[ "$(am_gitea GET /repos/platform/$REPO | jq -r .private)" = true ] \
  && am_ok "Repository platform/$REPO is still private" \
  || bad "Repository platform/$REPO is public: the security review's requirement is gone"
kubectl -n argocd get secrets -l 'argocd.argoproj.io/secret-type in (repository,repo-creds)' -o json >"$AM_TMP/secrets.json" 2>/dev/null
users="$(jq -r --arg u "${URL%.git}" '.items[] | select((.data.url // "" | @base64d | rtrimstr(".git")) as $s | ($u | startswith($s))) | (.data.username // "" | @base64d)' "$AM_TMP/secrets.json")"
if [ -z "$users" ]; then
  bad "Argo CD holds no credentials for the $REPO repository: it cannot read anything from it"
elif echo "$users" | grep -qx 'player'; then
  bad "Argo CD authenticates with the human admin account 'player'; the machine user exists for this"
elif ! echo "$users" | grep -qx 'tidewater-reader'; then
  bad "Argo CD has credentials for the repository, but not those of the read-only machine user"
else
  am_ok "Argo CD reads the repository as the read-only machine user"
fi

# ── the bootstrap: one root Application, everything else comes from Git ─────
if ! am_app_exists "$ROOT"; then
  bad "There is no Application named '$ROOT' in namespace argocd: nothing on this cluster is managed from Git"
else
  repo="$(am_app "$ROOT" '{.spec.source.repoURL}')"
  if [ "${repo%.git}" != "${URL%.git}" ]; then
    bad "Application '$ROOT' reads from '$repo', not from the $REPO repository as Argo CD sees it"
  else
    sync="$(am_app_sync "$ROOT")"; rev="$(am_app_rev "$ROOT")"; head="$(am_repo_head $REPO)"
    if [ "$sync" != Synced ]; then
      bad "Application '$ROOT' is ${sync:-Unknown}: $(am_app_conditions "$ROOT" | head -1 | cut -c1-160)"
    elif [ "$rev" != "$head" ]; then
      bad "Application '$ROOT' is synced to ${rev:0:7}, but $REPO/main is at ${head:0:7}"
    elif [ "$(am_app_health "$ROOT")" != Healthy ]; then
      bad "Application '$ROOT' health is $(am_app_health "$ROOT"): a child it manages is not healthy"
    else
      am_ok "Application '$ROOT' is Synced and Healthy at $REPO@${head:0:7}"
    fi
    kinds="$(am_app_json "$ROOT" | jq -r '[.status.resources[]?.kind] | unique | join(",")')"
    [ "$kinds" = "AppProject,Application" ] || bad "The resources of '$ROOT' are of kinds [$kinds]; expected exactly AppProject and Application"
  fi
fi

# ── the project boundary ────────────────────────────────────────────────────
tid="$(kubectl -n argocd get appproject tidewater -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null || true)"
if [ "$tid" != "$ROOT:argoproj.io/AppProject:argocd/tidewater" ]; then
  bad "AppProject 'tidewater' does not exist or is not managed by '$ROOT'"
else
  if kubectl -n argocd get appproject tidewater -o json | jq -e '[.spec.destinations[]? | select((.namespace // "") == "*" or (.namespace // "") == "")] | length > 0' >/dev/null; then
    bad "Project tidewater allows every namespace: it is no longer a boundary for the platform"
  fi
fi

# ── the three components ────────────────────────────────────────────────────
for spec in "tidewater-ledger tidewater-ledger 'tidewater-ledger v3.1'" "tidewater-batch tidewater-jobs 'tidewater-batch v1.8'" "tidewater-gateway tidewater-edge 'tidewater-gateway v2.0'"; do
  eval "set -- $spec"
  app="$1"; ns="$2"; want="$3"
  if ! am_app_exists "$app"; then bad "Application '$app' does not exist"; continue; fi
  tid="$(am_app "$app" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}')"
  [ "$tid" = "$ROOT:argoproj.io/Application:argocd/$app" ] || bad "Application '$app' is not managed by '$ROOT'"
  [ "$(am_app "$app" '{.spec.destination.namespace}')" = "$ns" ] || bad "Application '$app' no longer deploys to namespace $ns"
  sync="$(am_app_sync "$app")"; rev="$(am_app_rev "$app")"; head="$(am_repo_head $REPO)"; health="$(am_app_health "$app")"
  if [ "$sync" = Synced ] && [ "$rev" = "$head" ] && [ "$health" = Healthy ]; then
    am_ok "Application '$app' is Synced and Healthy at $REPO@${head:0:7}"
    body="$(am_http "http://$app.$ns" "$ns" 2)" || body="(no answer)"
    [ "$body" = "$want" ] || bad "Service $app in $ns answers '$body'"
    # a fresh cluster must be able to rebuild this: the namespace has to come from Git, not from a hand-typed command
    nstid="$(kubectl get namespace "$ns" -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null || true)"
    opts="$(am_app "$app" '{.spec.syncPolicy.syncOptions[*]}')"
    case " $opts " in *" CreateNamespace=true "*) ;; *) [ -n "$nstid" ] || bad "Namespace $ns was created by hand: a rebuild of the cluster from Git would fail again" ;; esac
  else
    bad "Application '$app' is ${sync:-Unknown}/${health:-Unknown} (${ns} does not serve '$want'): $(am_app_conditions "$app" | head -1 | cut -c1-170)"
  fi
done

[ "$bad" -eq 0 ] || { echo "❌ $bad problem(s) left on the new cluster"; exit 1; }
am_pass "The new cluster rebuilds from Git alone: root, projects and three components are live"
