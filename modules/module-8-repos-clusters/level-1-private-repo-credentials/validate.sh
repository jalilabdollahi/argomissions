#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=vault-ui
URL="$(am_repo_url vault-ui)"

[ "$(am_gitea GET /repos/platform/vault-ui | jq -r .private)" = true ] \
  || am_fail "Repository platform/vault-ui is public: the security review's requirement is gone"
am_ok "Repository platform/vault-ui is still private"

am_app_exists "$APP" || am_fail "Application '$APP' does not exist"
[ "$(am_app "$APP" '{.spec.source.repoURL}')" = "$URL" ] || am_fail "Application '$APP' no longer reads the vault-ui repository"

# which credentials does Argo CD hold for this repository? (repository secrets and credential templates)
kubectl -n argocd get secrets -l 'argocd.argoproj.io/secret-type in (repository,repo-creds)' -o json >"$AM_TMP/secrets.json" 2>/dev/null
users="$(jq -r --arg u "${URL%.git}" '.items[] | select((.data.url // "" | @base64d | rtrimstr(".git")) as $s | ($u | startswith($s))) | (.data.username // "" | @base64d)' "$AM_TMP/secrets.json")"
[ -n "$users" ] || am_fail "Argo CD holds no credentials for the vault-ui repository (application cannot read it)"
echo "$users" | grep -qx 'player' && am_fail "Argo CD authenticates with the human admin account 'player'; the machine user exists for this"
echo "$users" | grep -qx 'argo-reader' || am_fail "Argo CD has credentials for the repository, but not those of the read-only machine user"
am_ok "Argo CD uses the read-only machine user for the repository"

am_require_app_at_head "$APP" vault-ui
body="$(am_http http://vault-ui.vault-ui vault-ui)" || am_fail "Service vault-ui in namespace vault-ui does not answer"
[ "$body" = "vault-ui v2.4" ] || am_fail "Service vault-ui answers '$body'"
am_pass "vault-ui is live, read through the machine user, and the repo is still private"
