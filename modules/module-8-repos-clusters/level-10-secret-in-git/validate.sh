#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=smtp-gateway
NS=smtp-gw
OLD="Tr0ub4dor-smtp-2291"
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_repo_checkout smtp-gateway "$AM_TMP/head" || am_fail "Cannot read the smtp-gateway repo"
# History is evidence, not garbage: it must stay
[ -n "$(git -C "$AM_TMP/head" log --all -S"$OLD" --format=%H 2>/dev/null | head -1)" ] \
  || am_fail "The history of smtp-gateway no longer contains the original commit that leaked the password (it was rewritten)"
# Nothing sensitive at head
if grep -rqF "$OLD" --exclude-dir=.git "$AM_TMP/head"; then
  am_fail "The leaked password is still in a file at the head of smtp-gateway/main"
fi
docs="$(am_yaml_docs_json "$AM_TMP/head")"
[ "$(jq '[.[] | select(.kind == "Secret" and ((.data // {}) != {} or (.stringData // {}) != {}))] | length' <<<"$docs")" = 0 ] \
  || am_fail "A Secret manifest with data is still committed at the head of smtp-gateway/main"
am_ok "No credentials at the head of main; the history is untouched"

# The live Secret: present, rotated, and not owned by Git/Argo CD
kubectl -n "$NS" get secret smtp-credentials >/dev/null 2>&1 \
  || am_fail "Secret smtp-credentials does not exist in namespace $NS (the gateway cannot read its credentials)"
newpass="$(kubectl -n "$NS" get secret smtp-credentials -o json | jq -r '.data.password // "" | @base64d')"
user="$(kubectl -n "$NS" get secret smtp-credentials -o json | jq -r '.data.username // "" | @base64d')"
[ -n "$user" ] && [ -n "$newpass" ] || am_fail "Secret smtp-credentials lacks its 'username' or 'password' key"
[ "$newpass" != "$OLD" ] || am_fail "The live Secret still holds the leaked password"
[ "${#newpass}" -ge 12 ] || am_fail "The new password is too short to be a rotated credential"
if git -C "$AM_TMP/head" log --all -p 2>/dev/null | grep -qF -- "$newpass"; then
  am_fail "The new password is in the Git history of smtp-gateway: it leaked again"
fi
tracking="$(kubectl -n "$NS" get secret smtp-credentials -o json | jq -r '.metadata.annotations["argocd.argoproj.io/tracking-id"] // empty')"
[ -z "$tracking" ] || am_fail "Secret smtp-credentials is still managed by Argo CD from Git"
am_ok "Secret smtp-credentials holds a rotated password and is not tracked by Argo CD"

am_require_app_at_head "$APP" smtp-gateway
[ "$(am_app_json "$APP" | jq '[.status.resources[]? | select(.kind == "Secret")] | length')" = 0 ] \
  || am_fail "Application '$APP' still manages a Secret"

# The pods must run with the new value (environment variables are read at start)
stamp="$(kubectl -n "$NS" get secret smtp-credentials -o json | jq -r '[.metadata.creationTimestamp] + [.metadata.managedFields[]?.time] | map(select(. != null)) | max')"
stale="$(kubectl -n "$NS" get pods -l app=smtp-gateway -o json \
  | jq -r --arg t "$stamp" '[.items[] | select(.metadata.deletionTimestamp == null) | select((.status.containerStatuses[0].state.running.startedAt // "") < $t)] | length')"
[ "$stale" = 0 ] || am_fail "$stale pod(s) of smtp-gateway started before the password was rotated and still hold the old value"
[ "$(am_ready_replicas smtp-gateway "$NS")" -ge 2 ] || am_fail "Deployment smtp-gateway has fewer than 2 ready pods"
body="$(am_http http://smtp-gateway.smtp-gw "$NS")" || am_fail "Service smtp-gateway does not answer"
[ "$body" = "smtp-gateway v1.4" ] || am_fail "Service smtp-gateway answers '$body'"
am_pass "The leaked password is rotated, out of Git, and the gateway runs on the new one"
