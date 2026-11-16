#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=parcel-tracker
URL="$(am_repo_url parcel-tracker)"

[ "$(am_gitea GET /repos/platform/parcel-tracker | jq -r .private)" = true ] \
  || am_fail "Repository platform/parcel-tracker is public: it was private for a reason"
am_ok "Repository platform/parcel-tracker is still private"

am_app_exists "$APP" || am_fail "Application '$APP' does not exist"
[ "$(am_app "$APP" '{.spec.source.repoURL}')" = "$URL" ] || am_fail "Application '$APP' no longer reads the parcel-tracker repository"

# a credential Argo CD actually recognises: a repository secret or credential template with the right label
kubectl -n argocd get secrets -l 'argocd.argoproj.io/secret-type in (repository,repo-creds)' -o json >"$AM_TMP/secrets.json" 2>/dev/null
users="$(jq -r --arg u "${URL%.git}" '.items[] | select((.data.url // "" | @base64d | rtrimstr(".git")) as $s | ($u | startswith($s))) | (.data.username // "" | @base64d)' "$AM_TMP/secrets.json")"
[ -n "$users" ] || am_fail "Argo CD does not recognise any credentials for the parcel-tracker repository (argocd repo list does not show it)"
echo "$users" | grep -qx 'player' && am_fail "Argo CD authenticates with the human admin account 'player' instead of the machine user"
echo "$users" | grep -qx 'argo-reader' || am_fail "The credentials Argo CD recognises are not the read-only machine user's"
am_ok "Argo CD recognises the read-only machine user's credentials"

am_require_app_at_head "$APP" parcel-tracker
body="$(am_http http://parcel-tracker.parcels parcels)" || am_fail "Service parcel-tracker in namespace parcels does not answer"
[ "$body" = "parcel-tracker v0.9" ] || am_fail "Service parcel-tracker answers '$body'"
am_pass "parcel-tracker is live and Argo CD can read its private repo"
