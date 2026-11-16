#!/bin/bash
set -uo pipefail
source "$AM_LIB"

LEAKED='Summer2024!db'
fails=0
bad() { echo "❌ $*"; fails=$((fails+1)); }
good() { am_ok "$*"; }

# ── Finding 1: who can do what in Argo CD ───────────────────────────────────────
as_user() { local who="$1"; shift; env -u ARGOCD_OPTS argocd "$@" --config "$AM_TMP/$who-cli" --plaintext; }
logins_ok=1
for who in kim sam deploy-bot; do
  as_user "$who" login "$AM_ARGOCD_ADDR" --username "$who" --password "$who-pw-5521" >/dev/null 2>&1 || { bad "Access: cannot log in as '$who' (password $who-pw-5521)"; logins_ok=0; }
done
caps="$(kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.accounts\.deploy-bot}' 2>/dev/null)"
case "$caps" in *apiKey*login*|*login*apiKey*) ;; *) bad "Access: account deploy-bot lost its apiKey/login capabilities in argocd-cm" ;; esac

# access_pass → fills $AM_TMP/access.txt with one line per violated expectation
access_pass() {
  set -f   # "get clusters *": the star must not be expanded by the shell
  : >"$AM_TMP/access.txt"
  local who want res rest
  while IFS='|' read -r who want rest; do
    res="$(as_user "$who" account can-i $rest 2>/dev/null)"
    [ "$res" = "$want" ] || echo "$who|$want|$rest" >>"$AM_TMP/access.txt"
  done <<'LIST'
sam|yes|get applications custody/custody-api
sam|yes|get projects custody
sam|yes|get clusters *
sam|no|sync applications custody/custody-api
sam|no|delete applications custody/custody-batch
sam|no|update applications custody/custody-api
sam|no|create applications custody/new-app
sam|no|create projects new-project
kim|yes|delete applications custody/custody-batch
kim|yes|sync applications custody/custody-api
kim|yes|create projects new-project
kim|yes|update clusters *
deploy-bot|yes|get applications custody/custody-api
deploy-bot|yes|sync applications custody/custody-api
deploy-bot|yes|sync applications custody/custody-batch
deploy-bot|no|delete applications custody/custody-api
deploy-bot|no|update applications custody/custody-api
deploy-bot|no|create applications custody/new-app
deploy-bot|no|override applications custody/custody-api
deploy-bot|no|sync applications default/anything
deploy-bot|no|create projects new-project
deploy-bot|no|update projects custody
deploy-bot|no|get clusters *
deploy-bot|no|get repositories *
LIST
  set +f
}
if [ "$logins_ok" = 1 ]; then
  access_pass
  if [ -s "$AM_TMP/access.txt" ]; then sleep 5; access_pass; fi   # policy changes take a few seconds to be picked up
  if [ -s "$AM_TMP/access.txt" ]; then
    while IFS='|' read -r who want rest; do
      case "$who|$want" in
        sam\|no) bad "Access: sam can '$rest' - a developer who only needs to look around is allowed to change things" ;;
        sam\|yes) bad "Access: sam cannot '$rest' - he must be able to look around" ;;
        kim\|*) bad "Access: kim (platform lead) cannot '$rest' - she must stay an administrator" ;;
        deploy-bot\|no) bad "Access: deploy-bot can '$rest' - the pipeline has more rights than a deploy needs" ;;
        deploy-bot\|yes) bad "Access: deploy-bot cannot '$rest' - the release pipeline is refused (PermissionDenied)" ;;
      esac
    done <"$AM_TMP/access.txt"
  else
    good "Access: sam is read-only, kim administers, deploy-bot only gets and syncs project custody"
  fi
fi

# ── Finding 2: the database password ────────────────────────────────────────────
am_repo_checkout custody-api "$AM_TMP/api" >/dev/null 2>&1 || am_fail "cannot clone custody-api"
am_yaml_docs_json "$AM_TMP/api" >"$AM_TMP/api-docs.json"
secrets_in_git="$(jq -r '[.[] | select(.kind=="Secret" and ((.data // {}) | length > 0 or ((.stringData // {}) | length > 0)))] | length' "$AM_TMP/api-docs.json")"
[ "$secrets_in_git" = 0 ] || bad "Secrets: custody-api still contains a Secret manifest with its values in Git ($secrets_in_git)"
if grep -rqF --exclude-dir=.git -e "$LEAKED" "$AM_TMP/api"; then
  bad "Secrets: the database password that was committed is still readable in the head of custody-api"
fi
if grep -rqF --exclude-dir=.git -e "$(printf '%s' "$LEAKED" | base64)" "$AM_TMP/api"; then
  bad "Secrets: the database password is still in the head of custody-api, merely base64-encoded"
fi
live="$(kubectl -n custody get secret custody-db -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)"
if [ -z "$live" ]; then
  bad "Secrets: Secret custody-db does not exist in namespace custody - the API cannot start a new pod"
elif [ "$live" = "$LEAKED" ]; then
  bad "Secrets: the live database password is still the one that was committed to Git (it was never rotated)"
elif [ "${#live}" -lt 12 ]; then
  bad "Secrets: the live database password is shorter than 12 characters"
else
  [ "$secrets_in_git" = 0 ] && good "Secrets: custody-db holds a rotated password and Git does not contain one"
fi
stuck="$(kubectl -n custody get pods -o json 2>/dev/null | jq -r '[.items[].status.containerStatuses[]? | select(.state.waiting.reason=="CreateContainerConfigError")] | length')"
[ "${stuck:-0}" = 0 ] || bad "Secrets: a custody pod cannot start (CreateContainerConfigError)"

# ── Finding 3: how Argo CD authenticates to Git ─────────────────────────────────
kubectl -n argocd get secrets -l 'argocd.argoproj.io/secret-type in (repository,repo-creds)' -o json >"$AM_TMP/secrets.json" 2>/dev/null
human="$(jq -r '.items[] | select((.data.username // "" | @base64d) == "player") | .metadata.name' "$AM_TMP/secrets.json")"
[ -z "$human" ] || bad "Repo credentials: Argo CD logs in to Git as the human admin account 'player' (Secret(s) $(echo $human | tr '\n' ' '))"
per_repo="$(jq -r '.items[] | select(.metadata.labels["argocd.argoproj.io/secret-type"]=="repository") | select((.data.username // "") != "" or (.data.password // "") != "") | .metadata.name' "$AM_TMP/secrets.json")"
[ -z "$per_repo" ] || bad "Repo credentials: logins are stored once per repository (Secret(s) $(echo $per_repo | tr '\n' ' ')) - a new repo means another secret to rotate"
BASE="$(am_repo_url x)"; BASE="${BASE%/x.git}"
covers=0
while IFS=$'\t' read -r url user; do
  [ -n "$url" ] || continue
  [ "$user" = argo-reader ] || continue
  case "$(am_repo_url custody-api)" in "$url"*) case "$(am_repo_url custody-batch)" in "$url"*) covers=1 ;; esac ;; esac
done < <(jq -r '.items[] | select(.metadata.labels["argocd.argoproj.io/secret-type"]=="repo-creds") | [(.data.url // "" | @base64d), (.data.username // "" | @base64d)] | @tsv' "$AM_TMP/secrets.json")
[ "$covers" = 1 ] || bad "Repo credentials: no credential template for the machine user argo-reader covers both custody repositories"
[ -z "$human" ] && [ -z "$per_repo" ] && [ "$covers" = 1 ] && good "Repo credentials: one template, read-only machine user"
for r in custody-api custody-batch; do
  [ "$(am_gitea GET "/repos/platform/$r" | jq -r .private)" = true ] || bad "Repo credentials: repository platform/$r was made public"
done

# ── Finding 4: what project custody may create cluster-wide ─────────────────────
kubectl -n argocd get appproject custody -o json >"$AM_TMP/proj.json" 2>/dev/null || am_fail "AppProject custody does not exist"
wild="$(jq -r '[.spec.clusterResourceWhitelist[]? | select(.group=="*" or .kind=="*")] | length' "$AM_TMP/proj.json")"
stray="$(jq -r '[.spec.clusterResourceWhitelist[]? | select(.group=="*" or .kind=="*" | not) | select((.group=="rbac.authorization.k8s.io" and (.kind=="ClusterRole" or .kind=="ClusterRoleBinding")) | not) | select((.group=="" and .kind=="Namespace") | not)] | length' "$AM_TMP/proj.json")"
missing=""
for k in ClusterRole ClusterRoleBinding; do
  n="$(jq -r --arg k "$k" '[.spec.clusterResourceWhitelist[]? | select(.group=="rbac.authorization.k8s.io" and .kind==$k)] | length' "$AM_TMP/proj.json")"
  [ "$n" -ge 1 ] || missing="$missing $k"
done
if [ "$wild" != 0 ]; then bad "Project: custody lets its Applications create any kind of cluster-wide object (ClusterRoles, CRDs, webhooks ...)"
elif [ "$stray" != 0 ]; then bad "Project: custody allows cluster-wide kinds the custody services do not use"
elif [ -n "$missing" ]; then bad "Project: custody refuses cluster-wide objects its repository contains (${missing# }): the next sync will fail"
else good "Project: custody allows exactly the cluster-wide kinds it deploys"
fi
for a in custody-api custody-batch; do
  [ "$(am_app "$a" '{.spec.project}')" = custody ] || bad "Project: Application $a is no longer in project custody"
done

# ── The platform itself ─────────────────────────────────────────────────────────
for pair in custody-api:custody-api custody-batch:custody-batch; do
  app="${pair%%:*}"; repo="${pair##*:}"
  head="$(am_repo_head "$repo")"
  sync="$(am_app_sync "$app")"; health="$(am_app_health "$app")"; rev="$(am_app_rev "$app")"
  if [ "$sync" != Synced ] || [ "$health" != Healthy ] || [ "$rev" != "$head" ]; then
    bad "Platform: Application $app is ${sync:-?}/${health:-?} at ${rev:0:7} (head ${head:0:7}) $(am_app_conditions "$app" | head -1 | cut -c1-160)"
  fi
done
kubectl get clusterrolebinding custody-metrics-reader >/dev/null 2>&1 || bad "Platform: ClusterRoleBinding custody-metrics-reader is gone"
for pair in custody-api:"custody-api v3.1" custody-batch:"custody-batch v1.2"; do
  svc="${pair%%:*}"; want="${pair#*:}"
  body="$(am_http "http://$svc.custody" custody 2 2>/dev/null)"
  [ "$body" = "$want" ] || bad "Platform: Service $svc answers '${body:-nothing}' instead of '$want'"
done

[ "$fails" = 0 ] || { echo "   $fails finding(s) still open"; exit 1; }
am_pass "all audit findings are closed and the platform is healthy"
