#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=mailroom
URL="$(am_repo_url mailroom)"

[ "$(am_gitea GET /repos/platform/mailroom | jq -r .private)" = true ] \
  || am_fail "Repository platform/mailroom is public: it was private for a reason"
am_ok "Repository platform/mailroom is still private"

am_app_exists "$APP" || am_fail "Application '$APP' does not exist"
[ "$(am_app "$APP" '{.spec.source.repoURL}')" = "$URL" ] || am_fail "Application '$APP' no longer reads the mailroom repository"

kubectl -n argocd get secrets -l 'argocd.argoproj.io/secret-type in (repository,repo-creds)' -o json >"$AM_TMP/secrets.json" 2>/dev/null
users="$(jq -r --arg u "${URL%.git}" '.items[] | select((.data.url // "" | @base64d | rtrimstr(".git")) as $s | ($u | startswith($s))) | (.data.username // "" | @base64d)' "$AM_TMP/secrets.json")"
[ -n "$users" ] || am_fail "Argo CD holds no credentials for the mailroom repository"
echo "$users" | grep -qx 'player' && am_fail "Argo CD authenticates with the human admin account 'player' instead of the machine user"
echo "$users" | grep -qx 'argo-reader' || am_fail "Argo CD's credentials for the repository are not the read-only machine user's"
am_ok "Argo CD reads the repository as the read-only machine user"

am_require_app_at_head "$APP" mailroom
body="$(am_http http://mailroom.mailroom mailroom)" || am_fail "Service mailroom in namespace mailroom does not answer"
[ "$body" = "mailroom v3.2" ] || am_fail "Service mailroom answers '$body'"
am_pass "mailroom v3.2 is live and Argo CD can read the repository again"
