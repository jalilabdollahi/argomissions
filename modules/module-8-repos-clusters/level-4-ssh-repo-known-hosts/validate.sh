#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=fleet-agent
HOST=gitea.gitea.svc.cluster.local

am_app_exists "$APP" || am_fail "Application '$APP' does not exist"
case "$(am_app "$APP" '{.spec.source.repoURL}')" in
  ssh://git@$HOST:22/platform/fleet-agent.git|ssh://git@$HOST/platform/fleet-agent.git) ;;
  *) am_fail "Application '$APP' no longer reads the repository over SSH" ;;
esac
[ "$(am_gitea GET /repos/platform/fleet-agent | jq -r .private)" = true ] || am_fail "Repository platform/fleet-agent is public"

sec="$(kubectl -n argocd get secret repo-fleet-agent -o json 2>/dev/null)" || am_fail "The repository Secret repo-fleet-agent is gone"
[ "$(jq -r '.data.insecure // "" | @base64d' <<<"$sec")" != "true" ] \
  || am_fail "The repository is set to ignore host keys (insecure): SSH host verification is switched off"
[ -n "$(jq -r '.data.sshPrivateKey // ""' <<<"$sec")" ] || am_fail "The repository Secret no longer carries the deploy key"
am_ok "The repository still uses its deploy key and host key checking is on"

# the trusted host key must be the Git server's real key, not any key
kubectl -n argocd get cm argocd-ssh-known-hosts-cm -o jsonpath='{.data.ssh_known_hosts}' >"$AM_TMP/known" 2>/dev/null
kubectl -n gitea exec deploy/gitea -- sh -c 'cat /var/lib/gitea/ssh/gitea.*.pub' >"$AM_TMP/real" 2>/dev/null \
  || am_fail "validator could not read the Git server's host keys"
trusted=0
while read -r h t k _; do
  [ -n "${k:-}" ] || continue
  case "$h" in "$HOST"|"[$HOST]:22"|*"$HOST"*) ;; *) continue ;; esac
  grep -q "^$t $k" "$AM_TMP/real" && trusted=1
done <"$AM_TMP/known"
[ "$trusted" = 1 ] || am_fail "No known-hosts entry for $HOST matches the Git server's actual host key"
am_ok "Argo CD trusts the real host key of $HOST"

am_require_app_at_head "$APP" fleet-agent
body="$(am_http http://fleet-agent.fleet fleet)" || am_fail "Service fleet-agent in namespace fleet does not answer"
[ "$body" = "fleet-agent v5.0" ] || am_fail "Service fleet-agent answers '$body'"
am_pass "fleet-agent is live over SSH with host key verification"
