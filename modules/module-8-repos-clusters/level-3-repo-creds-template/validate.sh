#!/bin/bash
set -uo pipefail
source "$AM_LIB"

REPOS="kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports"
n=0
for r in $REPOS; do
  n=$((n+1))
  [ "$(am_gitea GET "/repos/platform/$r" | jq -r .private)" = true ] || am_fail "Repository platform/$r is public"
done
am_ok "All five repositories are still private"

kubectl -n argocd get secrets -l 'argocd.argoproj.io/secret-type in (repository,repo-creds)' -o json >"$AM_TMP/secrets.json" 2>/dev/null

# no per-repository credentials: any repository secret that carries a login is the manual way
per_repo="$(jq -r '.items[] | select(.metadata.labels["argocd.argoproj.io/secret-type"] == "repository") | select((.data.username // "") != "" or (.data.password // "") != "") | .metadata.name' "$AM_TMP/secrets.json")"
[ -z "$per_repo" ] || am_fail "Credentials are stored per repository (Secret(s): $(echo $per_repo | tr '\n' ' ')); the org should need one entry"

# one credential template whose URL is a prefix of every repository
BASE="$(am_repo_url x)"; BASE="${BASE%/x.git}"
tmpl="$(jq -r '.items[] | select(.metadata.labels["argocd.argoproj.io/secret-type"] == "repo-creds") | [.metadata.name, (.data.url // "" | @base64d), (.data.username // "" | @base64d)] | @tsv' "$AM_TMP/secrets.json")"
[ -n "$tmpl" ] || am_fail "Argo CD has no credential template (repo-creds) for the organisation"
covers=0
while IFS=$'\t' read -r name url user; do
  [ -n "$name" ] || continue
  [ "$user" = player ] && am_fail "Credential template '$name' uses the human admin account 'player'"
  ok=1
  for r in $REPOS; do
    case "$(am_repo_url "$r")" in "$url"*) ;; *) ok=0 ;; esac
  done
  [ "$ok" = 1 ] && [ "$user" = argo-reader ] && covers=1
done <<<"$tmpl"
[ "$covers" = 1 ] || am_fail "No credential template with the machine user covers all five repositories"
am_ok "One credential template (repo-creds) for the organisation covers all five repositories"

i=0
for r in $REPOS; do
  i=$((i+1))
  am_require_app_at_head "$r" "$r"
  body="$(am_http "http://$r.kiosk" kiosk)" || am_fail "Service $r in namespace kiosk does not answer"
  [ "$body" = "$r v1.$i" ] || am_fail "Service $r answers '$body'"
done
am_pass "All five kiosk services are live through one credential template"
